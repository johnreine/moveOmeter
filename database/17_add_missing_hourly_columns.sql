-- ============================================
-- Migration 17: Add Missing Hourly Aggregate Columns
-- ============================================
-- Purpose: Add columns that the app expects for hourly aggregates

-- Add missing columns from Migration 07 schema
ALTER TABLE daily_aggregates
ADD COLUMN IF NOT EXISTS avg_body_movement DECIMAL(5,2),
ADD COLUMN IF NOT EXISTS total_motion_events INTEGER,
ADD COLUMN IF NOT EXISTS total_presence_time_sec INTEGER;

-- Update generate_hourly_aggregates to populate these columns
CREATE OR REPLACE FUNCTION generate_hourly_aggregates(
    target_device_id TEXT,
    target_date DATE
) RETURNS void AS $$
BEGIN
    -- Insert hourly aggregates for each hour of the day
    INSERT INTO daily_aggregates (
        device_id, date, hour, house_id,
        avg_body_movement,
        total_motion_events,
        total_presence_time_sec,
        motion_score,
        total_active_minutes,
        average_movement_intensity,
        movement_sessions,
        fall_count,
        data_points_count,
        first_motion_time,
        last_motion_time
    )
    SELECT
        device_id,
        DATE(device_timestamp) as date,
        EXTRACT(HOUR FROM device_timestamp)::INTEGER as hour,
        NULL as house_id,

        -- Legacy columns (for app compatibility)
        AVG(NULLIF(body_movement, 0))::DECIMAL(5,2) as avg_body_movement,
        COUNT(*) FILTER (WHERE motion_detected > 0) as total_motion_events,
        COUNT(*) FILTER (WHERE human_existence > 0) as total_presence_time_sec,

        -- New columns
        LEAST(100, GREATEST(0,
            (COUNT(DISTINCT DATE_TRUNC('minute', device_timestamp)) / 0.6) +
            (AVG(NULLIF(body_movement, 0)) / 4) +
            (COUNT(CASE WHEN body_movement > 0 THEN 1 END) / 40)
        ))::INTEGER as motion_score,

        COUNT(DISTINCT DATE_TRUNC('minute', device_timestamp)) FILTER (
            WHERE body_movement > 0 OR human_existence > 0
        ) as total_active_minutes,

        AVG(NULLIF(body_movement, 0)) as average_movement_intensity,

        COUNT(DISTINCT DATE_TRUNC('minute', device_timestamp)) FILTER (
            WHERE body_movement > 0
        ) as movement_sessions,

        COUNT(*) FILTER (WHERE fall_state > 0) as fall_count,
        COUNT(*) as data_points_count,

        MIN(device_timestamp) FILTER (WHERE body_movement > 0 OR human_existence > 0) as first_motion_time,
        MAX(device_timestamp) FILTER (WHERE body_movement > 0 OR human_existence > 0) as last_motion_time

    FROM mmwave_sensor_data
    WHERE device_id = target_device_id
        AND DATE(device_timestamp) = target_date
    GROUP BY device_id, DATE(device_timestamp), EXTRACT(HOUR FROM device_timestamp)
    ON CONFLICT (device_id, date, hour)
    DO UPDATE SET
        avg_body_movement = EXCLUDED.avg_body_movement,
        total_motion_events = EXCLUDED.total_motion_events,
        total_presence_time_sec = EXCLUDED.total_presence_time_sec,
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

-- Regenerate today's hourly data with new columns
DO $$
DECLARE
  v_device RECORD;
BEGIN
  RAISE NOTICE 'Regenerating today hourly data with new columns...';

  FOR v_device IN
    SELECT device_id FROM moveometers WHERE device_status = 'active'
  LOOP
    IF EXISTS (
      SELECT 1 FROM mmwave_sensor_data
      WHERE device_id = v_device.device_id
        AND DATE(COALESCE(device_timestamp, created_at)) = CURRENT_DATE
    ) THEN
      PERFORM generate_hourly_aggregates(v_device.device_id, CURRENT_DATE);
      RAISE NOTICE '  ✓ Updated %', v_device.device_id;
    END IF;
  END LOOP;

  RAISE NOTICE 'Regeneration complete!';
END $$;

-- Verify
SELECT
  device_id,
  date,
  hour,
  avg_body_movement,
  total_motion_events,
  total_presence_time_sec
FROM daily_aggregates
WHERE device_id = 'ESP32C6_001'
  AND date = CURRENT_DATE
  AND hour IS NOT NULL
ORDER BY hour
LIMIT 5;
