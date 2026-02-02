-- ============================================
-- moveOmeter Device Management Schema
-- ============================================
-- Creates tables for managing moveOmeter devices, models, and configurations

-- ============================================
-- 1. moveOmeter Models Table
-- ============================================
-- Defines different hardware models and their capabilities
CREATE TABLE IF NOT EXISTS moveometer_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_name VARCHAR(100) NOT NULL UNIQUE,
    model_number VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,

    -- Hardware Capabilities (checkboxes)
    has_fall_detection BOOLEAN DEFAULT false,
    has_sleep_monitoring BOOLEAN DEFAULT false,
    has_position_tracking BOOLEAN DEFAULT false,
    has_heart_rate BOOLEAN DEFAULT false,
    has_respiration BOOLEAN DEFAULT false,
    has_apnea_detection BOOLEAN DEFAULT false,

    -- Sensor Hardware
    mmwave_sensor_model VARCHAR(50),  -- e.g., "SEN0623", "SEN0610"
    processor_model VARCHAR(50),      -- e.g., "ESP32-C6"

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- ============================================
-- 2. moveOmeters Table (Physical Devices)
-- ============================================
-- Each entry represents one physical moveOmeter device
CREATE TABLE IF NOT EXISTS moveometers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Device Identification
    device_id VARCHAR(50) NOT NULL UNIQUE,  -- e.g., "ESP32C6_001"
    serial_number VARCHAR(100) UNIQUE,
    uuid UUID DEFAULT gen_random_uuid(),
    mac_address VARCHAR(17),  -- XX:XX:XX:XX:XX:XX

    -- Model Reference
    model_id UUID REFERENCES moveometer_models(id),

    -- Manufacturing Info
    manufacture_date DATE,
    manufacture_batch VARCHAR(50),
    sim_card_number VARCHAR(50),  -- For cellular models

    -- Location & Assignment
    house_id UUID,  -- Future: FK to houses table
    location_name VARCHAR(100),  -- e.g., "bedroom_1", "bathroom"

    -- Operational Configuration
    operational_mode VARCHAR(20) NOT NULL DEFAULT 'fall_detection',  -- 'sleep' or 'fall_detection'
    data_interval_ms INTEGER DEFAULT 1000,  -- Milliseconds between readings

    -- ========================================
    -- FALL DETECTION MODE Configuration
    -- ========================================
    fall_config JSONB DEFAULT '{"enabled": true, "sensitivity": 5}'::jsonb,
    fall_sensitivity INTEGER DEFAULT 5,  -- 1-9 scale
    fall_break_height_cm INTEGER DEFAULT 100,
    install_height_cm INTEGER DEFAULT 250,  -- Height from floor in cm
    install_angle INTEGER DEFAULT 0,  -- Tilt angle in degrees

    -- ========================================
    -- SLEEP MONITORING MODE Configuration
    -- ========================================
    config_sleep JSONB DEFAULT '{"enabled": true, "quality_threshold": 70}'::jsonb,
    sleep_detection_distance_cm INTEGER DEFAULT 250,  -- Max distance for sleep detection
    breathing_alert_min INTEGER DEFAULT 10,  -- Alert if breathing < this
    breathing_alert_max INTEGER DEFAULT 25,  -- Alert if breathing > this
    heart_rate_alert_min INTEGER DEFAULT 60,
    heart_rate_alert_max INTEGER DEFAULT 100,
    apnea_alert_threshold INTEGER DEFAULT 3,  -- Number of apnea events to alert

    -- ========================================
    -- HUMAN DETECTION Configuration (Both Modes)
    -- ========================================
    human_config JSONB DEFAULT '{"timeout": 60}'::jsonb,
    human_detection_timeout_sec INTEGER DEFAULT 60,
    unattended_time_config JSONB DEFAULT '{"threshold": 300}'::jsonb,
    unattended_alert_threshold_sec INTEGER DEFAULT 300,  -- Alert if unattended > 5 min

    -- ========================================
    -- POSITION TRACKING Configuration
    -- ========================================
    position_tracking_enabled BOOLEAN DEFAULT true,
    track_frequency_hz INTEGER DEFAULT 1,
    room_width_ft DECIMAL(5,2) DEFAULT 15.0,
    room_length_ft DECIMAL(5,2) DEFAULT 20.0,

    -- ========================================
    -- NETWORK & CONNECTIVITY
    -- ========================================
    wifi_ssid VARCHAR(100),
    wifi_password_encrypted TEXT,  -- Store encrypted
    mqtt_broker VARCHAR(255),
    mqtt_port INTEGER DEFAULT 1883,

    -- ========================================
    -- AUTO-CALIBRATION
    -- ========================================
    auto_measured_height INTEGER,  -- Auto-detected ceiling height
    last_calibration_date TIMESTAMPTZ,
    calibration_status VARCHAR(50) DEFAULT 'pending',  -- 'pending', 'completed', 'failed'

    -- ========================================
    -- FIRMWARE & STATUS
    -- ========================================
    firmware_version VARCHAR(20),
    last_seen TIMESTAMPTZ,
    last_upload TIMESTAMPTZ,
    device_status VARCHAR(20) DEFAULT 'inactive',  -- 'active', 'inactive', 'error', 'maintenance'
    uptime_seconds BIGINT DEFAULT 0,

    -- ========================================
    -- METADATA
    -- ========================================
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT
);

-- ============================================
-- 3. Configuration History Table
-- ============================================
-- Track configuration changes over time
CREATE TABLE IF NOT EXISTS moveometer_config_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID REFERENCES moveometers(id) ON DELETE CASCADE,
    changed_by VARCHAR(100),  -- User or system that made the change
    change_timestamp TIMESTAMPTZ DEFAULT NOW(),
    field_changed VARCHAR(100),
    old_value TEXT,
    new_value TEXT,
    change_reason TEXT
);

-- ============================================
-- 4. Indexes for Performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_moveometers_device_id ON moveometers(device_id);
CREATE INDEX IF NOT EXISTS idx_moveometers_mac_address ON moveometers(mac_address);
CREATE INDEX IF NOT EXISTS idx_moveometers_house_id ON moveometers(house_id);
CREATE INDEX IF NOT EXISTS idx_moveometers_status ON moveometers(device_status);
CREATE INDEX IF NOT EXISTS idx_moveometers_last_seen ON moveometers(last_seen);
CREATE INDEX IF NOT EXISTS idx_moveometers_operational_mode ON moveometers(operational_mode);
CREATE INDEX IF NOT EXISTS idx_config_history_device_id ON moveometer_config_history(device_id);

-- ============================================
-- 5. Update Timestamp Trigger
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_moveometers_updated_at
    BEFORE UPDATE ON moveometers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_moveometer_models_updated_at
    BEFORE UPDATE ON moveometer_models
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 6. Configuration Change Tracking Trigger
-- ============================================
-- Automatically log configuration changes to history table
CREATE OR REPLACE FUNCTION log_config_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Log operational mode changes
    IF OLD.operational_mode IS DISTINCT FROM NEW.operational_mode THEN
        INSERT INTO moveometer_config_history (device_id, field_changed, old_value, new_value, changed_by)
        VALUES (NEW.id, 'operational_mode', OLD.operational_mode, NEW.operational_mode, 'system');
    END IF;

    -- Log data interval changes
    IF OLD.data_interval_ms IS DISTINCT FROM NEW.data_interval_ms THEN
        INSERT INTO moveometer_config_history (device_id, field_changed, old_value, new_value, changed_by)
        VALUES (NEW.id, 'data_interval_ms', OLD.data_interval_ms::TEXT, NEW.data_interval_ms::TEXT, 'system');
    END IF;

    -- Log install height changes
    IF OLD.install_height_cm IS DISTINCT FROM NEW.install_height_cm THEN
        INSERT INTO moveometer_config_history (device_id, field_changed, old_value, new_value, changed_by)
        VALUES (NEW.id, 'install_height_cm', OLD.install_height_cm::TEXT, NEW.install_height_cm::TEXT, 'system');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER track_moveometer_config_changes
    AFTER UPDATE ON moveometers
    FOR EACH ROW
    EXECUTE FUNCTION log_config_change();

-- ============================================
-- 7. Sample Model Data
-- ============================================
INSERT INTO moveometer_models (model_name, model_number, description,
    has_fall_detection, has_sleep_monitoring, has_position_tracking,
    has_heart_rate, has_respiration, has_apnea_detection,
    mmwave_sensor_model, processor_model)
VALUES
    ('moveOmeter Pro', 'MO-PRO-001', 'Full-featured model with all sensors',
     true, true, true, true, true, true,
     'SEN0623', 'ESP32-C6'),

    ('moveOmeter Basic', 'MO-BASIC-001', 'Basic fall detection only',
     true, false, true, false, false, false,
     'SEN0623', 'ESP32-C6')
ON CONFLICT (model_name) DO NOTHING;

-- ============================================
-- 8. Sample Device Data (for testing)
-- ============================================
-- Insert a sample device with your current ESP32C6_001
DO $$
DECLARE
    model_id_var UUID;
BEGIN
    -- Get the model ID for Pro model
    SELECT id INTO model_id_var FROM moveometer_models WHERE model_number = 'MO-PRO-001' LIMIT 1;

    -- Insert sample device
    INSERT INTO moveometers (
        device_id,
        serial_number,
        model_id,
        location_name,
        operational_mode,
        data_interval_ms,
        install_height_cm,
        firmware_version,
        device_status
    )
    VALUES (
        'ESP32C6_001',
        'SN-20260201-001',
        model_id_var,
        'bedroom_1',
        'fall_detection',
        1000,
        250,
        'v1.0.0',
        'active'
    )
    ON CONFLICT (device_id) DO UPDATE SET
        updated_at = NOW();
END $$;

-- ============================================
-- 9. Useful Views
-- ============================================

-- View: Active devices with their model info
CREATE OR REPLACE VIEW active_moveometers AS
SELECT
    m.device_id,
    m.location_name,
    m.operational_mode,
    m.device_status,
    m.last_seen,
    m.data_interval_ms,
    m.install_height_cm,
    mm.model_name,
    mm.model_number,
    mm.has_fall_detection,
    mm.has_sleep_monitoring
FROM moveometers m
LEFT JOIN moveometer_models mm ON m.model_id = mm.id
WHERE m.device_status = 'active';

-- View: Configuration summary for each device
CREATE OR REPLACE VIEW moveometer_config_summary AS
SELECT
    device_id,
    location_name,
    operational_mode,
    data_interval_ms,
    CASE
        WHEN operational_mode = 'fall_detection' THEN
            jsonb_build_object(
                'sensitivity', fall_sensitivity,
                'install_height_cm', install_height_cm,
                'position_tracking', position_tracking_enabled
            )
        WHEN operational_mode = 'sleep' THEN
            jsonb_build_object(
                'breathing_min', breathing_alert_min,
                'breathing_max', breathing_alert_max,
                'heart_rate_min', heart_rate_alert_min,
                'heart_rate_max', heart_rate_alert_max,
                'apnea_threshold', apnea_alert_threshold
            )
    END as mode_specific_config
FROM moveometers;

-- ============================================
-- DONE!
-- ============================================
-- Run this SQL in Supabase SQL Editor to create all tables
