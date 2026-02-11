-- ============================================
-- moveOmeter Complete Database Migration Script
-- ============================================
-- Run this ONCE in your Supabase SQL Editor to add all missing columns
-- This fixes the "Save Settings to Device" button error

-- ============================================
-- 1. Add Sampling Rate Configuration
-- ============================================
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS fall_detection_interval_ms INTEGER DEFAULT 20000,
ADD COLUMN IF NOT EXISTS sleep_mode_interval_ms INTEGER DEFAULT 20000,
ADD COLUMN IF NOT EXISTS config_check_interval_ms INTEGER DEFAULT 20000,
ADD COLUMN IF NOT EXISTS ota_check_interval_ms INTEGER DEFAULT 3600000;

COMMENT ON COLUMN moveometers.fall_detection_interval_ms IS 'Data collection interval in fall detection mode (milliseconds)';
COMMENT ON COLUMN moveometers.sleep_mode_interval_ms IS 'Data collection interval in sleep mode (milliseconds)';
COMMENT ON COLUMN moveometers.config_check_interval_ms IS 'How often to check for config updates from server (milliseconds)';
COMMENT ON COLUMN moveometers.ota_check_interval_ms IS 'How often to check for firmware updates (milliseconds)';

-- ============================================
-- 2. Add Sensor Query Configuration
-- ============================================
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS sensor_query_delay_ms INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS enable_supplemental_queries BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS supplemental_cycle_mode TEXT DEFAULT 'rotating',
ADD COLUMN IF NOT EXISTS query_retry_attempts INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS query_retry_delay_ms INTEGER DEFAULT 100;

COMMENT ON COLUMN moveometers.sensor_query_delay_ms IS 'Delay between individual sensor queries within a collection cycle (milliseconds)';
COMMENT ON COLUMN moveometers.enable_supplemental_queries IS 'Enable/disable supplemental data queries';
COMMENT ON COLUMN moveometers.supplemental_cycle_mode IS 'How to query supplemental data: "rotating", "all", or "none"';
COMMENT ON COLUMN moveometers.query_retry_attempts IS 'Number of times to retry failed sensor queries';
COMMENT ON COLUMN moveometers.query_retry_delay_ms IS 'Delay between sensor query retry attempts (milliseconds)';

CREATE INDEX IF NOT EXISTS idx_moveometers_sensor_config ON moveometers(device_id, enable_supplemental_queries);

-- ============================================
-- 3. Add Human Detection Thresholds
-- ============================================
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS seated_distance_threshold_cm INTEGER DEFAULT 100,
ADD COLUMN IF NOT EXISTS motion_distance_threshold_cm INTEGER DEFAULT 150;

COMMENT ON COLUMN moveometers.seated_distance_threshold_cm IS 'Horizontal distance threshold (cm) for detecting seated persons';
COMMENT ON COLUMN moveometers.motion_distance_threshold_cm IS 'Horizontal distance threshold (cm) for detecting moving persons';

-- Update existing devices with default values
UPDATE moveometers
SET
    seated_distance_threshold_cm = COALESCE(seated_distance_threshold_cm, 100),
    motion_distance_threshold_cm = COALESCE(motion_distance_threshold_cm, 150)
WHERE device_id IS NOT NULL;

-- ============================================
-- 4. Add Config Update Trigger Flag
-- ============================================
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS config_updated BOOLEAN DEFAULT false;

COMMENT ON COLUMN moveometers.config_updated IS 'Flag to trigger immediate config sync on device';

-- ============================================
-- 5. Create Timeline Annotations Table
-- ============================================
CREATE TABLE IF NOT EXISTS timeline_annotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    annotation_timestamp TIMESTAMPTZ NOT NULL,
    annotation_type TEXT NOT NULL DEFAULT 'custom',
    title TEXT NOT NULL,
    description TEXT,
    color TEXT DEFAULT '#667eea',
    icon TEXT DEFAULT '📝',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by TEXT
);

-- Add indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_timeline_annotations_device
    ON timeline_annotations(device_id, annotation_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_timeline_annotations_timestamp
    ON timeline_annotations(annotation_timestamp DESC);

-- Add RLS policies
ALTER TABLE timeline_annotations ENABLE ROW LEVEL SECURITY;

-- Allow all operations for now
CREATE POLICY IF NOT EXISTS "Enable all operations for timeline_annotations"
    ON timeline_annotations
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_timeline_annotations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_timeline_annotations_updated_at ON timeline_annotations;
CREATE TRIGGER trigger_update_timeline_annotations_updated_at
    BEFORE UPDATE ON timeline_annotations
    FOR EACH ROW
    EXECUTE FUNCTION update_timeline_annotations_updated_at();

-- Add comments
COMMENT ON TABLE timeline_annotations IS 'User-created annotations for timeline visualization';
COMMENT ON COLUMN timeline_annotations.annotation_type IS 'Type of annotation: custom, medication, appointment, note, fall, etc.';
COMMENT ON COLUMN timeline_annotations.color IS 'Hex color code for annotation display';
COMMENT ON COLUMN timeline_annotations.icon IS 'Emoji or icon for annotation marker';

-- ============================================
-- DONE!
-- ============================================
SELECT 'All migrations completed successfully! "Save Settings" and "Timeline Annotations" now work!' AS status;
