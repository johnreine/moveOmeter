-- Setup OTA for Quick Testing
-- This sets a 2-minute check interval instead of the default 1 hour

-- Set OTA check interval to 2 minutes (120000 ms) for testing
UPDATE moveometers
SET ota_check_interval_ms = 120000
WHERE device_id = 'ESP32C6_001';

-- Verify the setting
SELECT device_id,
       firmware_version,
       ota_check_interval_ms / 1000 as ota_check_interval_seconds,
       last_ota_check,
       ota_status
FROM moveometers
WHERE device_id = 'ESP32C6_001';

-- View all firmware versions
SELECT version,
       device_model,
       download_url,
       mandatory,
       created_at,
       release_notes
FROM firmware_updates
ORDER BY created_at DESC;

SELECT 'OTA testing configured! Device will check every 2 minutes.' AS status;
