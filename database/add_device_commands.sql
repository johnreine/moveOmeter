-- ============================================
-- Add Device Command System
-- ============================================
-- Allows web dashboard to send commands to ESP32

-- Add command field to moveometers table
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS pending_command TEXT DEFAULT NULL;

ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS command_timestamp TIMESTAMP WITH TIME ZONE;

-- Comment for clarity
COMMENT ON COLUMN moveometers.pending_command IS
'Command to be executed by device: "reset_sensor", "reconfigure", "reboot", etc. Cleared after execution.';

COMMENT ON COLUMN moveometers.command_timestamp IS
'Timestamp when command was issued by web dashboard';

-- Example: Send reset command to device
-- UPDATE moveometers
-- SET
--     pending_command = 'reconfigure',
--     command_timestamp = NOW()
-- WHERE device_id = 'ESP32C6_001';

SELECT 'Device command system added successfully!' AS status;
