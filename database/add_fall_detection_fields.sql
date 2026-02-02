-- Add Fall Detection Mode fields to mmwave_sensor_data table
-- Run this in your Supabase SQL Editor

-- Add sensor_mode field to distinguish between sleep and fall detection modes
ALTER TABLE mmwave_sensor_data
ADD COLUMN IF NOT EXISTS sensor_mode TEXT DEFAULT 'sleep';

-- Fall Detection Mode fields
ALTER TABLE mmwave_sensor_data
ADD COLUMN IF NOT EXISTS human_existence INTEGER,
ADD COLUMN IF NOT EXISTS motion_detected INTEGER,
ADD COLUMN IF NOT EXISTS body_movement INTEGER,
ADD COLUMN IF NOT EXISTS seated_distance_cm INTEGER,
ADD COLUMN IF NOT EXISTS motion_distance_cm INTEGER,
ADD COLUMN IF NOT EXISTS fall_state INTEGER,
ADD COLUMN IF NOT EXISTS fall_break_height_cm INTEGER,
ADD COLUMN IF NOT EXISTS static_residency INTEGER,
ADD COLUMN IF NOT EXISTS fall_sensitivity INTEGER,
ADD COLUMN IF NOT EXISTS fall_time_sec INTEGER,
ADD COLUMN IF NOT EXISTS static_residency_time_sec INTEGER,
ADD COLUMN IF NOT EXISTS install_height_cm INTEGER,
ADD COLUMN IF NOT EXISTS track_x INTEGER,
ADD COLUMN IF NOT EXISTS track_y INTEGER,
ADD COLUMN IF NOT EXISTS track_frequency_hz INTEGER;

-- Create index on sensor_mode for faster filtering
CREATE INDEX IF NOT EXISTS idx_sensor_mode ON mmwave_sensor_data(sensor_mode);

-- Create composite index for mode + device + time queries
CREATE INDEX IF NOT EXISTS idx_mode_device_time ON mmwave_sensor_data(sensor_mode, device_id, created_at DESC);

COMMENT ON COLUMN mmwave_sensor_data.sensor_mode IS 'Operating mode: sleep or fall_detection';
COMMENT ON COLUMN mmwave_sensor_data.fall_state IS 'Fall detection state: 0=no fall, 1=fall detected';
COMMENT ON COLUMN mmwave_sensor_data.track_x IS 'X coordinate of tracked person (cm)';
COMMENT ON COLUMN mmwave_sensor_data.track_y IS 'Y coordinate of tracked person (cm)';
