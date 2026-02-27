-- Migration: Add pressure sensor fields for door detection
-- Date: 2026-02-11
-- Purpose: Add DPS310 air pressure sensor data for detecting door open/close events

-- Add columns to mmwave_sensor_data table
ALTER TABLE mmwave_sensor_data
ADD COLUMN IF NOT EXISTS door_event INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS air_pressure_hpa FLOAT,
ADD COLUMN IF NOT EXISTS temperature_c FLOAT;

-- Add comments for documentation
COMMENT ON COLUMN mmwave_sensor_data.door_event IS 'Number of door open/close events detected since last upload (pressure changes > 0.3 hPa)';
COMMENT ON COLUMN mmwave_sensor_data.air_pressure_hpa IS 'Current air pressure in hPa - sent every 10 minutes for monitoring';
COMMENT ON COLUMN mmwave_sensor_data.temperature_c IS 'Current temperature in Celsius - sent every 10 minutes for monitoring';

-- Create index for querying door events
CREATE INDEX IF NOT EXISTS idx_door_event ON mmwave_sensor_data(device_id, created_at DESC) WHERE door_event > 0;

-- Rollback instructions:
-- ALTER TABLE mmwave_sensor_data DROP COLUMN door_event;
-- ALTER TABLE mmwave_sensor_data DROP COLUMN air_pressure_hpa;
-- ALTER TABLE mmwave_sensor_data DROP COLUMN temperature_c;
-- DROP INDEX IF EXISTS idx_door_event;
