-- ============================================
-- Add Human Detection Threshold Configuration
-- ============================================
-- Adds dmHumanConfig settings to moveometers table

-- Add seated distance threshold (for detecting people sitting)
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS seated_distance_threshold_cm INTEGER DEFAULT 100;

-- Add motion distance threshold (for detecting people moving)
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS motion_distance_threshold_cm INTEGER DEFAULT 150;

-- Update existing devices with default values
UPDATE moveometers
SET
    seated_distance_threshold_cm = 100,
    motion_distance_threshold_cm = 150
WHERE seated_distance_threshold_cm IS NULL
   OR motion_distance_threshold_cm IS NULL;

-- Add comments for clarity
COMMENT ON COLUMN moveometers.seated_distance_threshold_cm IS
'Horizontal distance threshold (cm) for detecting seated persons in fall detection mode';

COMMENT ON COLUMN moveometers.motion_distance_threshold_cm IS
'Horizontal distance threshold (cm) for detecting moving persons in fall detection mode';

-- Example: Configure device with custom thresholds
-- UPDATE moveometers
-- SET
--     seated_distance_threshold_cm = 120,  -- Detect seated people up to 1.2m away
--     motion_distance_threshold_cm = 200   -- Detect moving people up to 2m away
-- WHERE device_id = 'ESP32C6_001';

SELECT 'Human detection threshold configuration added successfully!' AS status;
