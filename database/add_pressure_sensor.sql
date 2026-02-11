-- Migration: Add pressure sensor fields for door detection
-- Date: 2026-02-11
-- Purpose: Add DPS310 air pressure sensor data for detecting door open/close events

-- Add columns to mmwave_sensor_data table
ALTER TABLE mmwave_sensor_data
ADD COLUMN IF NOT EXISTS air_pressure_hpa FLOAT,
ADD COLUMN IF NOT EXISTS pressure_change_hpa FLOAT,
ADD COLUMN IF NOT EXISTS door_events INTEGER DEFAULT 0;

-- Add comments for documentation
COMMENT ON COLUMN mmwave_sensor_data.air_pressure_hpa IS 'Current air pressure in hPa (hectopascals) from DPS310 sensor';
COMMENT ON COLUMN mmwave_sensor_data.pressure_change_hpa IS 'Maximum pressure change in hPa during collection interval';
COMMENT ON COLUMN mmwave_sensor_data.door_events IS 'Number of door open/close events detected (pressure changes > 0.3 hPa)';

-- Create index for querying door events
CREATE INDEX IF NOT EXISTS idx_door_events ON mmwave_sensor_data(device_id, created_at DESC) WHERE door_events > 0;

-- Rollback instructions:
-- ALTER TABLE mmwave_sensor_data DROP COLUMN air_pressure_hpa;
-- ALTER TABLE mmwave_sensor_data DROP COLUMN pressure_change_hpa;
-- ALTER TABLE mmwave_sensor_data DROP COLUMN door_events;
-- DROP INDEX IF EXISTS idx_door_events;
