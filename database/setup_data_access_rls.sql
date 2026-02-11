-- ============================================
-- Row Level Security Policies for Data Access
-- ============================================
-- This grants authenticated users access to device data based on their role
-- and the device_access permissions table

-- ============================================
-- 1. Enable RLS on all data tables
-- ============================================
ALTER TABLE moveometers ENABLE ROW LEVEL SECURITY;
ALTER TABLE moveometer_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE moveometer_config_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE mmwave_sensor_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE timeline_annotations ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 2. moveometers table policies
-- ============================================

-- Admin and Employee can see all devices
DROP POLICY IF EXISTS "Admins and employees can view all devices" ON moveometers;
CREATE POLICY "Admins and employees can view all devices"
    ON moveometers FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'employee')
            AND is_active = true
        )
    );

-- Caretakers and Caretakees can see devices they have access to
DROP POLICY IF EXISTS "Users can view devices they have access to" ON moveometers;
CREATE POLICY "Users can view devices they have access to"
    ON moveometers FOR SELECT
    TO authenticated
    USING (
        device_id IN (
            SELECT device_id FROM device_access
            WHERE user_id = auth.uid()
        )
    );

-- Admin and Employee can update devices
DROP POLICY IF EXISTS "Admins and employees can update devices" ON moveometers;
CREATE POLICY "Admins and employees can update devices"
    ON moveometers FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'employee')
            AND is_active = true
        )
    );

-- Admin and Employee can insert devices
DROP POLICY IF EXISTS "Admins and employees can insert devices" ON moveometers;
CREATE POLICY "Admins and employees can insert devices"
    ON moveometers FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'employee')
            AND is_active = true
        )
    );

-- ============================================
-- 3. moveometer_models table policies
-- ============================================

-- All authenticated users can view models
DROP POLICY IF EXISTS "Authenticated users can view models" ON moveometer_models;
CREATE POLICY "Authenticated users can view models"
    ON moveometer_models FOR SELECT
    TO authenticated
    USING (true);

-- Only admins can manage models
DROP POLICY IF EXISTS "Admins can manage models" ON moveometer_models;
CREATE POLICY "Admins can manage models"
    ON moveometer_models FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role = 'admin'
            AND is_active = true
        )
    );

-- ============================================
-- 4. mmwave_sensor_data table policies
-- ============================================

-- Admin and Employee can see all data
DROP POLICY IF EXISTS "Admins and employees can view all sensor data" ON mmwave_sensor_data;
CREATE POLICY "Admins and employees can view all sensor data"
    ON mmwave_sensor_data FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'employee')
            AND is_active = true
        )
    );

-- Users can see data for devices they have access to
DROP POLICY IF EXISTS "Users can view sensor data for their devices" ON mmwave_sensor_data;
CREATE POLICY "Users can view sensor data for their devices"
    ON mmwave_sensor_data FOR SELECT
    TO authenticated
    USING (
        device_id IN (
            SELECT device_id FROM device_access
            WHERE user_id = auth.uid()
        )
    );

-- Allow inserts from devices (using anon key)
DROP POLICY IF EXISTS "Devices can insert sensor data" ON mmwave_sensor_data;
CREATE POLICY "Devices can insert sensor data"
    ON mmwave_sensor_data FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

-- ============================================
-- 6. timeline_annotations table policies
-- ============================================

-- First, add user_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'timeline_annotations' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE timeline_annotations ADD COLUMN user_id UUID REFERENCES auth.users(id);
    END IF;
END $$;

-- Drop the overly permissive existing policy
DROP POLICY IF EXISTS "Enable all operations for timeline_annotations" ON timeline_annotations;

-- Admin and Employee can see all annotations
DROP POLICY IF EXISTS "Admins and employees can view all annotations" ON timeline_annotations;
CREATE POLICY "Admins and employees can view all annotations"
    ON timeline_annotations FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'employee')
            AND is_active = true
        )
    );

-- Users can see annotations for devices they have access to
DROP POLICY IF EXISTS "Users can view annotations for their devices" ON timeline_annotations;
CREATE POLICY "Users can view annotations for their devices"
    ON timeline_annotations FOR SELECT
    TO authenticated
    USING (
        device_id IN (
            SELECT device_id FROM device_access
            WHERE user_id = auth.uid()
        )
    );

-- Users can create annotations for devices they have access to
DROP POLICY IF EXISTS "Users can create annotations for their devices" ON timeline_annotations;
CREATE POLICY "Users can create annotations for their devices"
    ON timeline_annotations FOR INSERT
    TO authenticated
    WITH CHECK (
        device_id IN (
            SELECT device_id FROM device_access
            WHERE user_id = auth.uid()
        )
    );

-- Users can update their own annotations (check user_id if exists, otherwise created_by)
DROP POLICY IF EXISTS "Users can update their own annotations" ON timeline_annotations;
CREATE POLICY "Users can update their own annotations"
    ON timeline_annotations FOR UPDATE
    TO authenticated
    USING (
        user_id = auth.uid()
        OR (user_id IS NULL AND created_by = auth.uid()::TEXT)
    );

-- Users can delete their own annotations (check user_id if exists, otherwise created_by)
DROP POLICY IF EXISTS "Users can delete their own annotations" ON timeline_annotations;
CREATE POLICY "Users can delete their own annotations"
    ON timeline_annotations FOR DELETE
    TO authenticated
    USING (
        user_id = auth.uid()
        OR (user_id IS NULL AND created_by = auth.uid()::TEXT)
    );

-- ============================================
-- 7. Config history policies
-- ============================================

-- Admin and Employee can see all config history
DROP POLICY IF EXISTS "Admins and employees can view config history" ON moveometer_config_history;
CREATE POLICY "Admins and employees can view config history"
    ON moveometer_config_history FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'employee')
            AND is_active = true
        )
    );

-- System can insert config history
DROP POLICY IF EXISTS "System can insert config history" ON moveometer_config_history;
CREATE POLICY "System can insert config history"
    ON moveometer_config_history FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

-- ============================================
-- 8. Grant device_access to test user
-- ============================================
-- This grants your current user access to ESP32C6_001
-- Replace with actual user ID after checking

DO $$
DECLARE
    user_id_var UUID;
BEGIN
    -- Find the first active user (adjust this query to match your actual user)
    SELECT id INTO user_id_var FROM user_profiles WHERE is_active = true LIMIT 1;

    IF user_id_var IS NOT NULL THEN
        -- Grant access to ESP32C6_001
        INSERT INTO device_access (user_id, device_id, access_level, granted_by)
        VALUES (user_id_var, 'ESP32C6_001', 'admin', user_id_var)
        ON CONFLICT (user_id, device_id) DO UPDATE SET
            access_level = 'admin';

        RAISE NOTICE 'Granted device access to user %', user_id_var;
    END IF;
END $$;

SELECT 'Data access RLS policies configured!' AS status;
