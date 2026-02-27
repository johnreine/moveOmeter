-- ============================================
-- Migration 08: Add Fall Detection Timing Config
-- ============================================
-- Adds the missing fall_time_sec, residence_time_sec, and residence_switch
-- columns to moveometers. Also corrects fall_sensitivity range to 0-3.
-- Run in Supabase SQL Editor.

-- Fall time: delay (seconds) after fall detected before reporting
-- Prevents false triggers from sitting down quickly, stumbles, etc.
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS fall_time_sec INTEGER DEFAULT 5
    CHECK (fall_time_sec BETWEEN 1 AND 30);

-- Residence time: seconds someone must be motionless before "lying on floor" alert
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS residence_time_sec INTEGER DEFAULT 30
    CHECK (residence_time_sec BETWEEN 10 AND 600);

-- Residence switch: enable/disable the static residency (lying on floor) detection
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS residence_switch BOOLEAN DEFAULT true;

-- Fix fall_sensitivity: valid range is 0-3 per DFRobot SEN0623 spec
-- 0 = least sensitive, 3 = most sensitive
ALTER TABLE moveometers
    ALTER COLUMN fall_sensitivity SET DEFAULT 3;

-- Update any existing devices that have out-of-range values
UPDATE moveometers
SET fall_sensitivity = 3
WHERE fall_sensitivity > 3 OR fall_sensitivity IS NULL;

-- Add check constraint (drop first in case it exists from a previous attempt)
ALTER TABLE moveometers
    DROP CONSTRAINT IF EXISTS fall_sensitivity_range;
ALTER TABLE moveometers
    ADD CONSTRAINT fall_sensitivity_range
        CHECK (fall_sensitivity BETWEEN 0 AND 3);

-- Apply defaults to existing devices
UPDATE moveometers
SET
    fall_time_sec = 5,
    residence_time_sec = 30,
    residence_switch = true
WHERE fall_time_sec IS NULL;

COMMENT ON COLUMN moveometers.fall_time_sec IS
'Delay in seconds after fall detected before reporting. Prevents false triggers. Range: 1-30.';
COMMENT ON COLUMN moveometers.residence_time_sec IS
'Seconds someone must be motionless before static residency (lying on floor) alert. Range: 10-600.';
COMMENT ON COLUMN moveometers.residence_switch IS
'Enable/disable static residency detection (detects if someone is lying on the floor motionless).';
COMMENT ON COLUMN moveometers.fall_sensitivity IS
'Fall detection sensitivity. Range: 0 (least sensitive) to 3 (most sensitive, more false positives).';

SELECT 'Migration 08 complete: fall timing config added' AS status;
