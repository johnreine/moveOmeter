-- ============================================
-- Migration 16: Add Hourly Breakdown to Daily Aggregates
-- ============================================
-- Purpose: Add hour column and populate hourly aggregates for device detail charts

-- ============================================
-- 1. Add hour column (nullable for backward compatibility)
-- ============================================
ALTER TABLE daily_aggregates
ADD COLUMN IF NOT EXISTS hour INTEGER CHECK (hour IS NULL OR (hour >= 0 AND hour < 24));

-- Create index for hourly queries
CREATE INDEX IF NOT EXISTS idx_daily_aggregates_device_date_hour
ON daily_aggregates(device_id, date, hour);

-- ============================================
-- 2. Update unique constraint to include hour
-- ============================================
-- Drop old constraint (device_id, date)
ALTER TABLE daily_aggregates
DROP CONSTRAINT IF EXISTS daily_aggregates_device_id_date_key;

-- Add new constraint (device_id, date, hour)
-- Note: This allows both daily (hour=NULL) and hourly (hour=0-23) records
ALTER TABLE daily_aggregates
ADD CONSTRAINT daily_aggregates_device_date_hour_unique
UNIQUE NULLS NOT DISTINCT (device_id, date, hour);

-- ============================================
-- 3. Create function to generate hourly aggregates
-- ============================================
CREATE OR REPLACE FUNCTION generate_hourly_aggregates(
    target_device_id TEXT,
    target_date DATE
) RETURNS void AS $$
BEGIN
    -- Insert hourly aggregates for each hour of the day
    INSERT INTO daily_aggregates (
        device_id, date, hour, house_id,
        motion_score, total_active_minutes,
        average_movement_intensity, movement_sessions,
        fall_count, data_points_count,
        first_motion_time, last_motion_time
    )
    SELECT
        device_id,
        DATE(device_timestamp) as date,
        EXTRACT(HOUR FROM device_timestamp)::INTEGER as hour,
        NULL as house_id, -- hourly aggregates are device-level only

        -- Motion score for this hour (0-100)
        LEAST(100, GREATEST(0,
            (COUNT(DISTINCT DATE_TRUNC('minute', device_timestamp)) / 0.6) + -- Active minutes (up to 60)
            (AVG(NULLIF(body_movement, 0)) / 4) + -- Intensity (up to 25)
            (COUNT(CASE WHEN body_movement > 0 THEN 1 END) / 40) -- Activity points (up to 15)
        ))::INTEGER as motion_score,

        -- Active minutes in this hour
        COUNT(DISTINCT DATE_TRUNC('minute', device_timestamp)) FILTER (
            WHERE body_movement > 0 OR human_existence > 0
        ) as total_active_minutes,

        -- Average movement intensity
        AVG(NULLIF(body_movement, 0)) as average_movement_intensity,

        -- Movement sessions (approximate - count of active minute buckets)
        COUNT(DISTINCT DATE_TRUNC('minute', device_timestamp)) FILTER (
            WHERE body_movement > 0
        ) as movement_sessions,

        -- Fall count
        COUNT(*) FILTER (WHERE fall_state > 0) as fall_count,

        -- Data point count
        COUNT(*) as data_points_count,

        -- First motion time in this hour
        MIN(device_timestamp) FILTER (WHERE body_movement > 0 OR human_existence > 0) as first_motion_time,

        -- Last motion time in this hour
        MAX(device_timestamp) FILTER (WHERE body_movement > 0 OR human_existence > 0) as last_motion_time

    FROM mmwave_sensor_data
    WHERE device_id = target_device_id
        AND DATE(device_timestamp) = target_date
    GROUP BY device_id, DATE(device_timestamp), EXTRACT(HOUR FROM device_timestamp)
    ON CONFLICT (device_id, date, hour)
    DO UPDATE SET
        motion_score = EXCLUDED.motion_score,
        total_active_minutes = EXCLUDED.total_active_minutes,
        average_movement_intensity = EXCLUDED.average_movement_intensity,
        movement_sessions = EXCLUDED.movement_sessions,
        fall_count = EXCLUDED.fall_count,
        data_points_count = EXCLUDED.data_points_count,
        first_motion_time = EXCLUDED.first_motion_time,
        last_motion_time = EXCLUDED.last_motion_time,
        updated_at = NOW();

    RAISE NOTICE 'Generated hourly aggregates for device % on date %', target_device_id, target_date;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 4. Backfill hourly aggregates for last 7 days
-- ============================================
DO $$
DECLARE
  v_device RECORD;
  v_day INTEGER;
  v_target_date DATE;
  v_total_hours INTEGER := 0;
BEGIN
  RAISE NOTICE 'Starting hourly aggregates backfill...';
  RAISE NOTICE 'Date range: % to %', CURRENT_DATE - 6, CURRENT_DATE;
  RAISE NOTICE '';

  -- Loop through all active devices
  FOR v_device IN
    SELECT device_id
    FROM moveometers
    WHERE device_status = 'active'
    ORDER BY device_id
  LOOP
    RAISE NOTICE 'Processing device: %', v_device.device_id;

    -- Generate hourly aggregates for last 7 days
    FOR v_day IN 0..6 LOOP
      v_target_date := CURRENT_DATE - v_day;

      -- Check if data exists for this day
      IF EXISTS (
        SELECT 1 FROM mmwave_sensor_data
        WHERE device_id = v_device.device_id
          AND DATE(COALESCE(device_timestamp, created_at)) = v_target_date
      ) THEN
        -- Generate hourly aggregates
        PERFORM generate_hourly_aggregates(v_device.device_id, v_target_date);

        -- Count how many hours were generated
        SELECT COUNT(*) INTO v_total_hours
        FROM daily_aggregates
        WHERE device_id = v_device.device_id
          AND date = v_target_date
          AND hour IS NOT NULL;

        RAISE NOTICE '  ✓ Generated % hours for %', v_total_hours, v_target_date;
      ELSE
        RAISE NOTICE '  - No data for %', v_target_date;
      END IF;
    END LOOP;

    RAISE NOTICE '';
  END LOOP;

  RAISE NOTICE '========================================';
  RAISE NOTICE 'Hourly backfill complete!';
  RAISE NOTICE '========================================';
END $$;

-- Verify the backfill
SELECT
  device_id,
  date,
  hour,
  motion_score,
  total_active_minutes,
  data_points_count,
  CASE
    WHEN hour IS NULL AND house_id IS NULL THEN 'daily-device'
    WHEN hour IS NULL AND house_id IS NOT NULL THEN 'daily-house'
    WHEN hour IS NOT NULL THEN 'hourly'
  END as record_type
FROM daily_aggregates
WHERE device_id = 'ESP32C6_001'
  AND date = CURRENT_DATE
ORDER BY date DESC, hour NULLS FIRST;

-- Success message
DO $$ BEGIN
    RAISE NOTICE 'Hourly aggregates migration completed!';
    RAISE NOTICE 'App will now show 24-hour bar charts for each day';
END $$;
