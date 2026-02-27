-- ============================================
-- Migration 05: Update RLS Policies for New Role Names
-- ============================================
-- Purpose: Update all RLS policies to use "resident" instead of "caretakee"
-- Run this after 04_rename_caretakee_tables.sql

-- ============================================
-- 1. Update user_can_access_device function
-- ============================================
CREATE OR REPLACE FUNCTION user_can_access_device(user_uuid UUID, dev_id TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
    has_access BOOLEAN;
BEGIN
    -- Get user role
    SELECT role INTO user_role FROM user_profiles WHERE id = user_uuid;

    -- Admins and employees can access all devices
    IF user_role IN ('admin', 'employee') THEN
        RETURN true;
    END IF;

    -- Caretakers can access assigned devices
    IF user_role = 'caretaker' THEN
        SELECT EXISTS(
            SELECT 1 FROM device_access
            WHERE user_id = user_uuid AND device_id = dev_id
        ) INTO has_access;
        RETURN has_access;
    END IF;

    -- Residents can only access their own devices
    IF user_role = 'resident' THEN
        SELECT EXISTS(
            SELECT 1 FROM resident_devices
            WHERE resident_id = user_uuid AND device_id = dev_id
        ) INTO has_access;
        RETURN has_access;
    END IF;

    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 2. Update resident_devices RLS policies
-- ============================================
DROP POLICY IF EXISTS "Caretakees can view their devices" ON resident_devices;
DROP POLICY IF EXISTS "Residents can view their devices" ON resident_devices;
CREATE POLICY "Residents can view their devices"
    ON resident_devices FOR SELECT
    USING (resident_id = auth.uid());

DROP POLICY IF EXISTS "Admins can manage caretakee devices" ON resident_devices;
DROP POLICY IF EXISTS "Admins can manage resident devices" ON resident_devices;
CREATE POLICY "Admins can manage resident devices"
    ON resident_devices FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee')
        )
    );

-- ============================================
-- 3. Update moveometers RLS policies
-- ============================================
DROP POLICY IF EXISTS "Users can view authorized devices" ON moveometers;
CREATE POLICY "Users can view authorized devices"
    ON moveometers FOR SELECT
    USING (
        -- Admins and employees see all
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee')
        )
        OR
        -- Caretakers see assigned devices
        EXISTS (
            SELECT 1 FROM device_access
            WHERE user_id = auth.uid() AND device_id = moveometers.device_id
        )
        OR
        -- Residents see their own devices
        EXISTS (
            SELECT 1 FROM resident_devices
            WHERE resident_id = auth.uid() AND device_id = moveometers.device_id
        )
    );

-- ============================================
-- 4. Update houses RLS policies (if table exists)
-- ============================================
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'houses') THEN
        DROP POLICY IF EXISTS "Users can view authorized houses" ON houses;
        CREATE POLICY "Users can view authorized houses"
            ON houses FOR SELECT
            USING (
                -- Admins and employees see all houses
                EXISTS (
                    SELECT 1 FROM user_profiles
                    WHERE id = auth.uid() AND role IN ('admin', 'employee')
                )
                OR
                -- Users see houses they have access to
                EXISTS (
                    SELECT 1 FROM house_access
                    WHERE user_id = auth.uid() AND house_id = houses.id
                )
                OR
                -- Users see houses with devices they can access
                EXISTS (
                    SELECT 1 FROM moveometers m
                    WHERE m.house_id = houses.id
                    AND (
                        EXISTS (
                            SELECT 1 FROM device_access da
                            WHERE da.user_id = auth.uid() AND da.device_id = m.device_id
                        )
                        OR
                        EXISTS (
                            SELECT 1 FROM resident_devices rd
                            WHERE rd.resident_id = auth.uid() AND rd.device_id = m.device_id
                        )
                    )
                )
            );
        RAISE NOTICE 'Houses RLS policy updated';
    ELSE
        RAISE NOTICE 'Houses table does not exist - skipping RLS policy update';
    END IF;
END $$;

SELECT 'RLS policies updated for new role names!' AS status;
