-- ============================================
-- Fix Device Access RLS Policies for Admin Panel
-- ============================================
-- This fixes the 409 error when employees try to view device access
-- by allowing employees to view user profiles when managing device access

-- ============================================
-- 1. Update user_profiles policy to allow employees to view profiles
-- ============================================

-- Drop and recreate the policy to include employees
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
CREATE POLICY "Admins and employees can view all profiles"
    ON user_profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee')
        )
    );

-- Also need to allow employees to update profiles (for admin panel)
DROP POLICY IF EXISTS "Admins can manage all profiles" ON user_profiles;
CREATE POLICY "Admins and employees can manage all profiles"
    ON user_profiles FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee')
        )
    );

-- ============================================
-- 2. Ensure device_access policies are correct
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own access" ON device_access;
DROP POLICY IF EXISTS "Admins can manage device access" ON device_access;

-- Users can view their own device access
CREATE POLICY "Users can view their own access"
    ON device_access FOR SELECT
    USING (user_id = auth.uid());

-- Admins and employees can view ALL device access (for admin panel)
CREATE POLICY "Admins and employees can view all access"
    ON device_access FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee') AND is_active = true
        )
    );

-- Admins and employees can insert device access
CREATE POLICY "Admins and employees can insert device access"
    ON device_access FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee') AND is_active = true
        )
    );

-- Admins and employees can update device access
CREATE POLICY "Admins and employees can update device access"
    ON device_access FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee') AND is_active = true
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee') AND is_active = true
        )
    );

-- Admins and employees can delete device access
CREATE POLICY "Admins and employees can delete device access"
    ON device_access FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee') AND is_active = true
        )
    );

-- ============================================
-- 3. Add missing created_at column to device_access if it doesn't exist
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'device_access' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE device_access ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- Rename granted_at to created_at if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'device_access' AND column_name = 'granted_at'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'device_access' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE device_access RENAME COLUMN granted_at TO created_at;
    END IF;
END $$;

SELECT 'Device access RLS policies fixed!' AS status;
