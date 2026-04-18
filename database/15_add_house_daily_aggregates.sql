-- ============================================
-- Migration 15: Add House-Level Daily Aggregates
-- ============================================
-- Purpose: Store pre-computed house-level daily metrics to eliminate client-side aggregation
-- NO logic in the local viewer - all aggregation happens server-side

-- ============================================
-- 1. Add house_id to daily_aggregates
-- ============================================
ALTER TABLE daily_aggregates
ADD COLUMN IF NOT EXISTS house_id UUID REFERENCES houses(id);

-- Create index for house queries
CREATE INDEX IF NOT EXISTS idx_daily_aggregates_house_date
ON daily_aggregates(house_id, date DESC)
WHERE house_id IS NOT NULL;

-- Update constraint to allow either device_id OR house_id (but not both for the same record)
-- Note: device_id is still NOT NULL for device-level aggregates
-- For house-level aggregates, we'll set device_id to the house_id prefixed with 'HOUSE_'

-- ============================================
-- 2. Create function to calculate house-level daily metrics
-- ============================================
CREATE OR REPLACE FUNCTION calculate_house_daily_metrics(
  p_house_id UUID,
  p_date DATE
) RETURNS VOID AS $$
DECLARE
  v_device_ids TEXT[];
  v_motion_score INTEGER;
  v_first_motion TIMESTAMPTZ;
  v_last_motion TIMESTAMPTZ;
  v_total_active_minutes INTEGER;
  v_movement_sessions INTEGER;
  v_avg_movement DECIMAL(5,2);
  v_fall_count INTEGER;
  v_longest_stationary INTEGER;
  v_data_points INTEGER;
  v_offline_minutes INTEGER;
  v_peak_activity_hour INTEGER;
  v_device_count INTEGER;
BEGIN
  -- Get all devices for this house
  SELECT ARRAY_AGG(device_id)
  INTO v_device_ids
  FROM moveometers
  WHERE house_id = p_house_id;

  -- Check if house has any devices
  IF v_device_ids IS NULL OR array_length(v_device_ids, 1) = 0 THEN
    RAISE NOTICE 'No devices found for house % on date %', p_house_id, p_date;
    RETURN;
  END IF;

  v_device_count := array_length(v_device_ids, 1);

  -- Aggregate from device-level daily_aggregates
  -- This assumes device-level metrics are already calculated
  SELECT
    -- Average motion score across all devices
    ROUND(AVG(motion_score))::INTEGER,
    -- Earliest first motion across all devices
    MIN(first_motion_time),
    -- Latest last motion across all devices
    MAX(last_motion_time),
    -- Sum of active minutes across all devices
    SUM(total_active_minutes),
    -- Sum of movement sessions across all devices
    SUM(movement_sessions),
    -- Average movement intensity across all devices
    AVG(average_movement_intensity),
    -- Sum of fall counts across all devices
    SUM(fall_count),
    -- Maximum longest stationary period across all devices
    MAX(longest_stationary_minutes),
    -- Sum of data points across all devices
    SUM(data_points_count),
    -- Average offline minutes across all devices
    ROUND(AVG(offline_minutes))::INTEGER,
    -- Most common peak activity hour across all devices (mode)
    MODE() WITHIN GROUP (ORDER BY peak_activity_hour)
  INTO
    v_motion_score,
    v_first_motion,
    v_last_motion,
    v_total_active_minutes,
    v_movement_sessions,
    v_avg_movement,
    v_fall_count,
    v_longest_stationary,
    v_data_points,
    v_offline_minutes,
    v_peak_activity_hour
  FROM daily_aggregates
  WHERE device_id = ANY(v_device_ids)
    AND date = p_date
    AND house_id IS NULL; -- Only aggregate from device-level records

  -- If no device-level data exists, skip
  IF v_motion_score IS NULL THEN
    RAISE NOTICE 'No device-level metrics found for house % on date %', p_house_id, p_date;
    RETURN;
  END IF;

  -- Insert or update house-level aggregate
  -- Use 'HOUSE_' prefix for device_id to distinguish house-level from device-level
  INSERT INTO daily_aggregates (
    device_id,
    house_id,
    date,
    motion_score,
    first_motion_time,
    last_motion_time,
    total_active_minutes,
    longest_stationary_minutes,
    movement_sessions,
    average_movement_intensity,
    fall_count,
    data_points_count,
    offline_minutes,
    peak_activity_hour
  ) VALUES (
    'HOUSE_' || p_house_id,
    p_house_id,
    p_date,
    v_motion_score,
    v_first_motion,
    v_last_motion,
    v_total_active_minutes,
    v_longest_stationary,
    v_movement_sessions,
    v_avg_movement,
    v_fall_count,
    v_data_points,
    v_offline_minutes,
    v_peak_activity_hour
  )
  ON CONFLICT (device_id, date)
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
    offline_minutes = EXCLUDED.offline_minutes,
    peak_activity_hour = EXCLUDED.peak_activity_hour,
    updated_at = NOW(),
    calculated_at = NOW();

  RAISE NOTICE 'House-level metrics calculated for house % on date % (% devices, motion score=%)',
    p_house_id, p_date, v_device_count, v_motion_score;

END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 3. Update calculate_all_daily_metrics to also calculate house-level metrics
-- ============================================
-- Drop existing function first (return type is changing)
DROP FUNCTION IF EXISTS calculate_all_daily_metrics(DATE);

CREATE OR REPLACE FUNCTION calculate_all_daily_metrics(p_date DATE)
RETURNS TABLE (entity_id TEXT, entity_type TEXT, status TEXT) AS $$
DECLARE
  v_house RECORD;
BEGIN
  -- First, calculate device-level metrics
  RAISE NOTICE 'Calculating device-level metrics for date %', p_date;

  PERFORM calculate_daily_metrics(d.device_id, p_date)
  FROM (SELECT DISTINCT device_id FROM mmwave_sensor_data
        WHERE device_timestamp >= p_date::TIMESTAMPTZ
          AND device_timestamp < (p_date + INTERVAL '1 day')::TIMESTAMPTZ
       ) d;

  -- Return device results
  RETURN QUERY
  SELECT
    m.device_id,
    'device'::TEXT as entity_type,
    'calculated'::TEXT as status
  FROM moveometers m
  WHERE EXISTS (
    SELECT 1 FROM mmwave_sensor_data sd
    WHERE sd.device_id = m.device_id
      AND sd.device_timestamp >= p_date::TIMESTAMPTZ
      AND sd.device_timestamp < (p_date + INTERVAL '1 day')::TIMESTAMPTZ
  );

  -- Then, calculate house-level metrics for each house that has devices with data
  RAISE NOTICE 'Calculating house-level metrics for date %', p_date;

  FOR v_house IN
    SELECT DISTINCT h.id, h.name
    FROM houses h
    INNER JOIN moveometers m ON m.house_id = h.id
    WHERE EXISTS (
      SELECT 1 FROM daily_aggregates da
      WHERE da.device_id = m.device_id
        AND da.date = p_date
        AND da.house_id IS NULL
    )
  LOOP
    PERFORM calculate_house_daily_metrics(v_house.id, p_date);

    RETURN QUERY
    SELECT
      v_house.id,
      'house'::TEXT as entity_type,
      'calculated'::TEXT as status;
  END LOOP;

END;
$$ LANGUAGE plpgsql;

-- Success message
DO $$ BEGIN
    RAISE NOTICE 'House-level daily aggregates migration completed!';
    RAISE NOTICE 'Now calculating house-level metrics will happen server-side';
    RAISE NOTICE 'Use: SELECT calculate_house_daily_metrics(house_id, date) to calculate';
END $$;

-- ============================================
-- 4. Backfill house-level aggregates for last 7 days
-- ============================================
DO $$
DECLARE
  v_house RECORD;
  v_day INTEGER;
  v_target_date DATE;
BEGIN
  RAISE NOTICE 'Backfilling house-level aggregates for last 7 days...';

  FOR v_house IN SELECT id, name FROM houses LOOP
    RAISE NOTICE 'Processing house: % (%)', v_house.name, v_house.id;

    FOR v_day IN 0..6 LOOP
      v_target_date := CURRENT_DATE - v_day;

      -- Check if device-level data exists for this house on this day
      IF EXISTS (
        SELECT 1 FROM daily_aggregates da
        INNER JOIN moveometers m ON m.device_id = da.device_id
        WHERE m.house_id = v_house.id
          AND da.date = v_target_date
          AND da.house_id IS NULL
      ) THEN
        PERFORM calculate_house_daily_metrics(v_house.id, v_target_date);
      END IF;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Backfill complete!';
END $$;

-- Verify the backfill
SELECT
  device_id,
  house_id,
  date,
  motion_score,
  total_active_minutes,
  first_motion_time,
  last_motion_time
FROM daily_aggregates
WHERE house_id IS NOT NULL
ORDER BY house_id, date DESC;

-- Rollback instructions:
-- ALTER TABLE daily_aggregates DROP COLUMN IF EXISTS house_id;
-- DROP FUNCTION IF EXISTS calculate_house_daily_metrics(TEXT, DATE);
-- (Restore original calculate_all_daily_metrics if needed)
