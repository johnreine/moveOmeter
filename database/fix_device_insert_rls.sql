-- ============================================
-- Fix RLS for Device Data Uploads
-- ============================================
-- This fixes the 401 error when devices try to upload data
-- The issue was missing GRANT permissions for the anon role

-- Re-enable RLS on mmwave_sensor_data
ALTER TABLE mmwave_sensor_data ENABLE ROW LEVEL SECURITY;

-- ============================================
-- Grant table-level permissions
-- ============================================
-- RLS policies control row-level access, but you also need table-level permissions
GRANT INSERT ON mmwave_sensor_data TO anon;
GRANT SELECT ON mmwave_sensor_data TO authenticated;

-- ============================================
-- Device Insert Policy (for Arduino/ESP32 using anon key)
-- ============================================
DROP POLICY IF EXISTS "Devices can insert sensor data" ON mmwave_sensor_data;
CREATE POLICY "Devices can insert sensor data"
    ON mmwave_sensor_data FOR INSERT
    TO anon
    WITH CHECK (true);

-- ============================================
-- User Read Policies (based on role and device_access)
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

-- Caretakers and Caretakees can see data for devices they have access to
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

-- ============================================
-- Verify policies are active
-- ============================================
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename = 'mmwave_sensor_data'
ORDER BY policyname;

SELECT 'Device insert RLS fixed! Devices can now upload data.' AS status;
