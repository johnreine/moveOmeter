-- ============================================
-- Add Config Sync Trigger
-- ============================================
-- Adds a flag to trigger immediate config sync from ESP32

-- Add config_updated flag (web dashboard sets this when saving)
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS config_updated BOOLEAN DEFAULT false;

-- Add last_config_sync timestamp
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS last_config_sync TIMESTAMP WITH TIME ZONE;

-- Comment for clarity
COMMENT ON COLUMN moveometers.config_updated IS
'Set to true by web dashboard when settings change. ESP32 checks this flag and resyncs immediately.';

COMMENT ON COLUMN moveometers.last_config_sync IS
'Timestamp of last successful config sync by the device';

-- Example: Trigger immediate sync after web changes
-- UPDATE moveometers
-- SET config_updated = true
-- WHERE device_id = 'ESP32C6_001';

SELECT 'Config sync trigger added successfully!' AS status;
