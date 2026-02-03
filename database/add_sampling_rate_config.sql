-- Add sampling rate configuration fields to moveometers table
-- These control how frequently the device collects and uploads data

ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS fall_detection_interval_ms INTEGER DEFAULT 20000,
ADD COLUMN IF NOT EXISTS sleep_mode_interval_ms INTEGER DEFAULT 20000,
ADD COLUMN IF NOT EXISTS config_check_interval_ms INTEGER DEFAULT 20000,
ADD COLUMN IF NOT EXISTS ota_check_interval_ms INTEGER DEFAULT 3600000;

-- Add comments to describe the fields
COMMENT ON COLUMN moveometers.fall_detection_interval_ms IS 'Data collection interval in fall detection mode (milliseconds)';
COMMENT ON COLUMN moveometers.sleep_mode_interval_ms IS 'Data collection interval in sleep mode (milliseconds)';
COMMENT ON COLUMN moveometers.config_check_interval_ms IS 'How often to check for config updates from server (milliseconds)';
COMMENT ON COLUMN moveometers.ota_check_interval_ms IS 'How often to check for firmware updates (milliseconds)';
