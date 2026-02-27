-- ============================================
-- Migration 01: Create Device Types Table
-- ============================================
-- Purpose: Generalize from "moveometers" to "devices" with device types
-- Run this first before other migrations

-- Create device_types table
CREATE TABLE IF NOT EXISTS device_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_name VARCHAR(50) NOT NULL UNIQUE,  -- 'moveometer', 'camera', 'door_sensor', etc.
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50),  -- Icon identifier for UI
    has_sensor_data BOOLEAN DEFAULT true,
    data_table_name VARCHAR(100),  -- e.g., 'mmwave_sensor_data'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_device_types_type_name ON device_types(type_name);

-- Insert moveOmeter as first device type
INSERT INTO device_types (type_name, display_name, description, icon, data_table_name)
VALUES ('moveometer', 'moveOmeter', 'mmWave monitoring device for elderly care', 'sensors', 'mmwave_sensor_data')
ON CONFLICT (type_name) DO NOTHING;

-- Add updated_at trigger
CREATE TRIGGER update_device_types_updated_at
    BEFORE UPDATE ON device_types
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

SELECT 'Device types table created successfully!' AS status;
