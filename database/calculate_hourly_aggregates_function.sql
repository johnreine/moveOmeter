-- Function to calculate hourly aggregates for a specific device and date
-- This creates records with hour 0-23 for the 24-hour timeline graph

DROP FUNCTION IF EXISTS calculate_hourly_aggregates(TEXT, DATE);

CREATE OR REPLACE FUNCTION calculate_hourly_aggregates(
  p_device_id TEXT,
  p_date DATE
) RETURNS VOID AS $$
DECLARE
  v_start_of_day TIMESTAMPTZ;
  v_end_of_day TIMESTAMPTZ;
  v_house_id UUID;
  v_hour INTEGER;
  v_avg_movement DECIMAL(5,2);
  v_total_motion_events INTEGER;
  v_total_presence_sec INTEGER;
BEGIN
  -- Define day boundaries in Eastern timezone
  v_start_of_day := (p_date::DATE || ' 00:00:00')::TIMESTAMP AT TIME ZONE 'America/New_York';
  v_end_of_day := (p_date::DATE || ' 23:59:59')::TIMESTAMP AT TIME ZONE 'America/New_York' + INTERVAL '1 second';

  -- Get house_id for this device
  SELECT house_id INTO v_house_id
  FROM moveometers
  WHERE device_id = p_device_id
  LIMIT 1;

  -- Calculate metrics for each hour (0-23)
  FOR v_hour IN 0..23 LOOP
    -- Calculate average body movement for this hour
    SELECT
      COALESCE(AVG(body_movement), 0)::DECIMAL(5,2),
      COALESCE(SUM(CASE WHEN motion_detected > 0 THEN 1 ELSE 0 END), 0),
      COALESCE(SUM(CASE WHEN human_existence > 0 THEN 1 ELSE 0 END) * 30, 0)  -- Each reading ~30 seconds
    INTO v_avg_movement, v_total_motion_events, v_total_presence_sec
    FROM mmwave_sensor_data
    WHERE device_id = p_device_id
      AND device_timestamp >= v_start_of_day + (v_hour || ' hours')::INTERVAL
      AND device_timestamp < v_start_of_day + ((v_hour + 1) || ' hours')::INTERVAL;

    -- Insert or update hourly aggregate
    INSERT INTO daily_aggregates (
      device_id,
      date,
      hour,
      house_id,
      avg_body_movement,
      total_motion_events,
      total_presence_time_sec
    ) VALUES (
      p_device_id,
      p_date,
      v_hour,
      v_house_id,
      v_avg_movement,
      v_total_motion_events,
      v_total_presence_sec
    )
    ON CONFLICT (device_id, date, hour)
    DO UPDATE SET
      avg_body_movement = EXCLUDED.avg_body_movement,
      total_motion_events = EXCLUDED.total_motion_events,
      total_presence_time_sec = EXCLUDED.total_presence_time_sec,
      updated_at = NOW(),
      calculated_at = NOW();
  END LOOP;

  RAISE NOTICE 'Hourly aggregates calculated for device % on date %', p_device_id, p_date;

END;
$$ LANGUAGE plpgsql;

-- Helper function to calculate hourly aggregates for all devices for a given date
CREATE OR REPLACE FUNCTION calculate_all_hourly_aggregates(p_date DATE)
RETURNS VOID AS $$
BEGIN
  -- Execute calculation for each device that has data
  PERFORM calculate_hourly_aggregates(d.device_id, p_date)
  FROM (SELECT DISTINCT device_id FROM mmwave_sensor_data
        WHERE device_timestamp >= p_date::TIMESTAMPTZ
          AND device_timestamp < (p_date + INTERVAL '1 day')::TIMESTAMPTZ
       ) d;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_hourly_aggregates IS 'Calculates and stores hourly aggregate metrics (hour 0-23) for 24-hour timeline graphs';
COMMENT ON FUNCTION calculate_all_hourly_aggregates IS 'Calculates hourly aggregates for all devices that have data on the specified date';
