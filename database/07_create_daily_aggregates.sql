-- ============================================
-- Migration 07: Create Daily Aggregates Table
-- ============================================
-- Purpose: Pre-compute daily statistics for fast retrieval
-- This reduces query from 86,400 data points to 24 hourly aggregates
-- Run this after completing Stage 1 migrations

-- ============================================
-- 1. Create daily_aggregates table
-- ============================================
CREATE TABLE IF NOT EXISTS daily_aggregates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT REFERENCES moveometers(device_id) NOT NULL,
    date DATE NOT NULL,
    hour INTEGER CHECK (hour >= 0 AND hour < 24),  -- Hour of day (0-23)

    -- Aggregated metrics
    sensor_mode VARCHAR(20),  -- 'sleep' or 'fall_detection'

    -- Movement metrics
    avg_body_movement DECIMAL(5,2),
    max_body_movement INTEGER,
    total_motion_events INTEGER,
    total_presence_time_sec INTEGER,

    -- Sleep metrics (when in sleep mode)
    avg_heart_rate DECIMAL(5,2),
    min_heart_rate INTEGER,
    max_heart_rate INTEGER,
    avg_respiration DECIMAL(5,2),
    avg_sleep_quality DECIMAL(5,2),
    total_sleep_time_min INTEGER,
    apnea_events INTEGER,

    -- Fall detection metrics
    fall_events INTEGER,
    avg_static_residency_time DECIMAL(8,2),

    -- Data quality
    data_point_count INTEGER,
    first_reading_at TIMESTAMPTZ,
    last_reading_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(device_id, date, hour)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_daily_aggregates_device_date ON daily_aggregates(device_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_aggregates_date ON daily_aggregates(date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_aggregates_device_hour ON daily_aggregates(device_id, date, hour);

-- Add updated_at trigger
CREATE TRIGGER update_daily_aggregates_updated_at
    BEFORE UPDATE ON daily_aggregates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 2. Create aggregation function
-- ============================================
CREATE OR REPLACE FUNCTION generate_daily_aggregates(
    target_device_id TEXT,
    target_date DATE
) RETURNS void AS $$
BEGIN
    INSERT INTO daily_aggregates (
        device_id, date, hour, sensor_mode,
        avg_body_movement, max_body_movement, total_motion_events,
        total_presence_time_sec,
        avg_heart_rate, min_heart_rate, max_heart_rate,
        avg_respiration, avg_sleep_quality, total_sleep_time_min,
        apnea_events, fall_events,
        avg_static_residency_time, data_point_count,
        first_reading_at, last_reading_at
    )
    SELECT
        device_id,
        DATE(device_timestamp) as date,
        EXTRACT(HOUR FROM device_timestamp)::INTEGER as hour,
        sensor_mode,
        AVG(body_movement) as avg_body_movement,
        MAX(body_movement) as max_body_movement,
        SUM(CASE WHEN motion_detected = 1 THEN 1 ELSE 0 END) as total_motion_events,
        SUM(CASE WHEN human_existence = 1 THEN 1 ELSE 0 END) as total_presence_time_sec,
        AVG(NULLIF(heart_rate, 0)) as avg_heart_rate,
        MIN(NULLIF(heart_rate, 0)) as min_heart_rate,
        MAX(heart_rate) as max_heart_rate,
        AVG(NULLIF(respiration, 0)) as avg_respiration,
        AVG(NULLIF(sleep_quality, 0)) as avg_sleep_quality,
        SUM(CASE WHEN sleep_state = 1 THEN 1 ELSE 0 END) as total_sleep_time_min,
        SUM(CASE WHEN apnea_events > 0 THEN apnea_events ELSE 0 END) as apnea_events,
        SUM(CASE WHEN fall_state = 1 THEN 1 ELSE 0 END) as fall_events,
        AVG(static_residency_time_sec) as avg_static_residency_time,
        COUNT(*) as data_point_count,
        MIN(device_timestamp) as first_reading_at,
        MAX(device_timestamp) as last_reading_at
    FROM mmwave_sensor_data
    WHERE device_id = target_device_id
        AND DATE(device_timestamp) = target_date
    GROUP BY device_id, DATE(device_timestamp), EXTRACT(HOUR FROM device_timestamp), sensor_mode
    ON CONFLICT (device_id, date, hour)
    DO UPDATE SET
        avg_body_movement = EXCLUDED.avg_body_movement,
        max_body_movement = EXCLUDED.max_body_movement,
        total_motion_events = EXCLUDED.total_motion_events,
        total_presence_time_sec = EXCLUDED.total_presence_time_sec,
        avg_heart_rate = EXCLUDED.avg_heart_rate,
        min_heart_rate = EXCLUDED.min_heart_rate,
        max_heart_rate = EXCLUDED.max_heart_rate,
        avg_respiration = EXCLUDED.avg_respiration,
        avg_sleep_quality = EXCLUDED.avg_sleep_quality,
        total_sleep_time_min = EXCLUDED.total_sleep_time_min,
        apnea_events = EXCLUDED.apnea_events,
        fall_events = EXCLUDED.fall_events,
        avg_static_residency_time = EXCLUDED.avg_static_residency_time,
        data_point_count = EXCLUDED.data_point_count,
        last_reading_at = EXCLUDED.last_reading_at,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 3. Enable RLS
-- ============================================
ALTER TABLE daily_aggregates ENABLE ROW LEVEL SECURITY;

-- Users can view aggregates for devices they can access
DROP POLICY IF EXISTS "Users can view aggregates for authorized devices" ON daily_aggregates;
CREATE POLICY "Users can view aggregates for authorized devices"
    ON daily_aggregates FOR SELECT
    USING (
        user_can_access_device(auth.uid(), device_id)
    );

-- Admins can manage aggregates
DROP POLICY IF EXISTS "Admins can manage daily aggregates" ON daily_aggregates;
CREATE POLICY "Admins can manage daily aggregates"
    ON daily_aggregates FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee')
        )
    );

-- System can insert aggregates (for automated jobs)
DROP POLICY IF EXISTS "System can insert aggregates" ON daily_aggregates;
CREATE POLICY "System can insert aggregates"
    ON daily_aggregates FOR INSERT
    WITH CHECK (true);

SELECT 'Daily aggregates table created successfully!' AS status;

-- ============================================
-- 4. Example: Backfill last 7 days
-- ============================================
-- Uncomment to backfill data for your device
-- DO $$
-- DECLARE
--     day_offset INTEGER;
-- BEGIN
--     FOR day_offset IN 0..6 LOOP
--         PERFORM generate_daily_aggregates(
--             'ESP32C6_001',
--             CURRENT_DATE - day_offset
--         );
--     END LOOP;
-- END $$;
