-- ============================================
-- Migration 02: Add Device Type to Moveometers
-- ============================================
-- Purpose: Link existing moveometers to device_types table
-- Run this after 01_create_device_types.sql

-- Add device_type_id column (nullable initially)
ALTER TABLE moveometers ADD COLUMN IF NOT EXISTS device_type_id UUID REFERENCES device_types(id);

-- Set all existing devices to moveometer type
UPDATE moveometers
SET device_type_id = (SELECT id FROM device_types WHERE type_name = 'moveometer')
WHERE device_type_id IS NULL;

-- Make device_type_id required after backfill
ALTER TABLE moveometers ALTER COLUMN device_type_id SET NOT NULL;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_moveometers_device_type ON moveometers(device_type_id);

-- Note: Keeping table name as "moveometers" for backward compatibility
-- Future devices with different types will be added to this table

SELECT 'Device type ID added to moveometers successfully!' AS status,
       COUNT(*) as devices_updated
FROM moveometers
WHERE device_type_id IS NOT NULL;
