-- Function to calculate daily metrics for a specific device and date
-- This processes raw sensor data and populates the daily_aggregates table

-- Drop existing functions first to avoid signature conflicts
DROP FUNCTION IF EXISTS calculate_all_daily_metrics(DATE);
DROP FUNCTION IF EXISTS calculate_daily_metrics(TEXT, DATE);

CREATE OR REPLACE FUNCTION calculate_daily_metrics(
  p_device_id TEXT,
  p_date DATE
) RETURNS VOID AS $$
DECLARE
  v_motion_score INTEGER;
  v_first_motion TIMESTAMPTZ;
  v_last_motion TIMESTAMPTZ;
  v_total_active_minutes INTEGER;
  v_movement_sessions INTEGER;
  v_avg_movement DECIMAL(5,2);
  v_fall_count INTEGER;
  v_longest_stationary INTEGER;
  v_data_points INTEGER;
  v_start_of_day TIMESTAMPTZ;
  v_end_of_day TIMESTAMPTZ;
  v_offline_minutes INTEGER;
  v_peak_activity_hour INTEGER;
BEGIN
  -- Define day boundaries in Eastern timezone (where the user is located)
  -- Convert the date to Eastern time, then to UTC for querying
  v_start_of_day := (p_date::DATE || ' 00:00:00')::TIMESTAMP AT TIME ZONE 'America/New_York';
  v_end_of_day := (p_date::DATE || ' 23:59:59')::TIMESTAMP AT TIME ZONE 'America/New_York' + INTERVAL '1 second';

  -- Count total data points for the day
  SELECT COUNT(*)
  INTO v_data_points
  FROM mmwave_sensor_data
  WHERE device_id = p_device_id
    AND device_timestamp >= v_start_of_day
    AND device_timestamp < v_end_of_day;

  -- If no data, skip calculation
  IF v_data_points = 0 THEN
    RAISE NOTICE 'No data found for device % on date %', p_device_id, p_date;
    RETURN;
  END IF;

  -- Calculate first motion time (first record with movement > 0)
  SELECT MIN(device_timestamp)
  INTO v_first_motion
  FROM mmwave_sensor_data
  WHERE device_id = p_device_id
    AND device_timestamp >= v_start_of_day
    AND device_timestamp < v_end_of_day
    AND (body_movement > 0 OR human_existence > 0);

  -- Calculate last motion time
  SELECT MAX(device_timestamp)
  INTO v_last_motion
  FROM mmwave_sensor_data
  WHERE device_id = p_device_id
    AND device_timestamp >= v_start_of_day
    AND device_timestamp < v_end_of_day
    AND (body_movement > 0 OR human_existence > 0);

  -- Calculate total active minutes (periods with movement)
  SELECT COUNT(DISTINCT DATE_TRUNC('minute', device_timestamp))
  INTO v_total_active_minutes
  FROM mmwave_sensor_data
  WHERE device_id = p_device_id
    AND device_timestamp >= v_start_of_day
    AND device_timestamp < v_end_of_day
    AND (body_movement > 0 OR human_existence > 0);

  -- Calculate average movement intensity when active
  SELECT AVG(body_movement)
  INTO v_avg_movement
  FROM mmwave_sensor_data
  WHERE device_id = p_device_id
    AND device_timestamp >= v_start_of_day
    AND device_timestamp < v_end_of_day
    AND body_movement > 0;

  -- Count falls
  SELECT COUNT(*)
  INTO v_fall_count
  FROM mmwave_sensor_data
  WHERE device_id = p_device_id
    AND device_timestamp >= v_start_of_day
    AND device_timestamp < v_end_of_day
    AND fall_state > 0;

  -- Calculate longest stationary period (consecutive minutes without movement)
  -- This is a simplified version - could be enhanced with window functions
  WITH movement_minutes AS (
    SELECT
      DATE_TRUNC('minute', device_timestamp) as minute,
      MAX(body_movement) as max_movement
    FROM mmwave_sensor_data
    WHERE device_id = p_device_id
      AND device_timestamp >= v_start_of_day
      AND device_timestamp < v_end_of_day
    GROUP BY DATE_TRUNC('minute', device_timestamp)
    ORDER BY minute
  ),
  stationary_periods AS (
    SELECT
      minute,
      max_movement,
      CASE WHEN max_movement = 0 THEN 1 ELSE 0 END as is_stationary,
      SUM(CASE WHEN max_movement > 0 THEN 1 ELSE 0 END)
        OVER (ORDER BY minute) as movement_group
    FROM movement_minutes
  )
  SELECT COALESCE(MAX(stationary_count), 0)
  INTO v_longest_stationary
  FROM (
    SELECT COUNT(*) as stationary_count
    FROM stationary_periods
    WHERE is_stationary = 1
    GROUP BY movement_group
  ) sub;

  -- Calculate movement sessions (number of distinct active periods)
  -- Simplified: count transitions from no-movement to movement
  WITH movement_status AS (
    SELECT
      device_timestamp,
      CASE WHEN body_movement > 0 OR human_existence > 0 THEN 1 ELSE 0 END as is_moving,
      LAG(CASE WHEN body_movement > 0 OR human_existence > 0 THEN 1 ELSE 0 END)
        OVER (ORDER BY device_timestamp) as prev_moving
    FROM mmwave_sensor_data
    WHERE device_id = p_device_id
      AND device_timestamp >= v_start_of_day
      AND device_timestamp < v_end_of_day
  )
  SELECT COUNT(*)
  INTO v_movement_sessions
  FROM movement_status
  WHERE is_moving = 1 AND (prev_moving = 0 OR prev_moving IS NULL);

  -- Calculate peak activity hour (hour with most movement) in user's local timezone
  WITH hourly_activity AS (
    SELECT
      EXTRACT(HOUR FROM device_timestamp AT TIME ZONE 'America/New_York') as hour,
      SUM(body_movement) as total_movement
    FROM mmwave_sensor_data
    WHERE device_id = p_device_id
      AND device_timestamp >= v_start_of_day
      AND device_timestamp < v_end_of_day
    GROUP BY EXTRACT(HOUR FROM device_timestamp AT TIME ZONE 'America/New_York')
    ORDER BY total_movement DESC
    LIMIT 1
  )
  SELECT hour::INTEGER
  INTO v_peak_activity_hour
  FROM hourly_activity;

  -- Calculate offline minutes (minutes with no data points)
  -- We expect approximately 1 data point per 30 seconds = 2 per minute
  -- Count distinct minutes with data, then subtract from 1440 total minutes in a day
  WITH minutes_with_data AS (
    SELECT COUNT(DISTINCT DATE_TRUNC('minute', device_timestamp)) as covered_minutes
    FROM mmwave_sensor_data
    WHERE device_id = p_device_id
      AND device_timestamp >= v_start_of_day
      AND device_timestamp < v_end_of_day
  )
  SELECT 1440 - covered_minutes
  INTO v_offline_minutes
  FROM minutes_with_data;

  -- Calculate motion score (0-100 based on activity level)
  -- Formula: Weighted combination of active time, intensity, and sessions
  v_motion_score := LEAST(100, GREATEST(0,
    (v_total_active_minutes::DECIMAL / 12) + -- Active minutes (up to 50 points for 600 min)
    (v_avg_movement::DECIMAL / 4) + -- Intensity (up to 25 points)
    (v_movement_sessions::DECIMAL * 2) -- Sessions (up to 25 points for ~12 sessions)
  ))::INTEGER;

  -- Insert or update daily aggregate
  -- hour is explicitly set to NULL for daily rollups (vs hourly aggregates)
  INSERT INTO daily_aggregates (
    device_id,
    date,
    hour,
    motion_score,
    first_motion_time,
    last_motion_time,
    total_active_minutes,
    longest_stationary_minutes,
    movement_sessions,
    average_movement_intensity,
    fall_count,
    data_points_count,
    data_coverage_pct,
    offline_minutes,
    peak_activity_hour
  ) VALUES (
    p_device_id,
    p_date,
    NULL,  -- NULL hour = daily rollup (vs 0-23 for hourly aggregates)
    v_motion_score,
    v_first_motion,
    v_last_motion,
    v_total_active_minutes,
    v_longest_stationary,
    v_movement_sessions,
    v_avg_movement,
    v_fall_count,
    v_data_points,
    LEAST(100, (v_data_points::DECIMAL / 2880) * 100), -- Assuming ~30s intervals = 2880 points/day
    v_offline_minutes,
    v_peak_activity_hour
  )
  ON CONFLICT (device_id, date) WHERE hour IS NULL
  DO UPDATE SET
    motion_score = EXCLUDED.motion_score,
    first_motion_time = EXCLUDED.first_motion_time,
    last_motion_time = EXCLUDED.last_motion_time,
    total_active_minutes = EXCLUDED.total_active_minutes,
    longest_stationary_minutes = EXCLUDED.longest_stationary_minutes,
    movement_sessions = EXCLUDED.movement_sessions,
    average_movement_intensity = EXCLUDED.average_movement_intensity,
    fall_count = EXCLUDED.fall_count,
    data_points_count = EXCLUDED.data_points_count,
    data_coverage_pct = EXCLUDED.data_coverage_pct,
    offline_minutes = EXCLUDED.offline_minutes,
    peak_activity_hour = EXCLUDED.peak_activity_hour,
    updated_at = NOW(),
    calculated_at = NOW();

  RAISE NOTICE 'Daily metrics calculated for device % on date %: Motion Score=%',
    p_device_id, p_date, v_motion_score;

END;
$$ LANGUAGE plpgsql;

-- Helper function to calculate metrics for all devices for a given date
CREATE OR REPLACE FUNCTION calculate_all_daily_metrics(p_date DATE)
RETURNS TABLE (device_id TEXT, status TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT
    m.device_id,
    'calculated'::TEXT as status
  FROM moveometers m
  WHERE EXISTS (
    SELECT 1 FROM mmwave_sensor_data sd
    WHERE sd.device_id = m.device_id
      AND sd.device_timestamp >= p_date::TIMESTAMPTZ
      AND sd.device_timestamp < (p_date + INTERVAL '1 day')::TIMESTAMPTZ
  );

  -- Execute calculation for each device
  PERFORM calculate_daily_metrics(d.device_id, p_date)
  FROM (SELECT DISTINCT device_id FROM mmwave_sensor_data
        WHERE device_timestamp >= p_date::TIMESTAMPTZ
          AND device_timestamp < (p_date + INTERVAL '1 day')::TIMESTAMPTZ
       ) d;
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled job to run daily at 1 AM UTC
-- Note: This requires pg_cron extension
-- SELECT cron.schedule('calculate-daily-metrics', '0 1 * * *',
--   'SELECT calculate_all_daily_metrics(CURRENT_DATE - INTERVAL ''1 day'');'
-- );

COMMENT ON FUNCTION calculate_daily_metrics IS 'Calculates and stores daily aggregate metrics for a specific device and date';
COMMENT ON FUNCTION calculate_all_daily_metrics IS 'Calculates daily metrics for all devices that have data on the specified date';
