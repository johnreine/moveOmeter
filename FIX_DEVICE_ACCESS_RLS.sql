-- ============================================
-- Fix Device Access RLS Policies
-- ============================================
-- Update device_access policies to use the helper function

-- ============================================
-- 1. Drop existing device_access policies
-- ============================================

DROP POLICY IF EXISTS "Users can view their own access" ON device_access;
DROP POLICY IF EXISTS "Admins can manage device access" ON device_access;
DROP POLICY IF EXISTS "Admins and employees can view all access" ON device_access;
DROP POLICY IF EXISTS "Admins and employees can insert device access" ON device_access;
DROP POLICY IF EXISTS "Admins and employees can update device access" ON device_access;
DROP POLICY IF EXISTS "Admins and employees can delete device access" ON device_access;

-- ============================================
-- 2. Create new policies using the helper function
-- ============================================

-- Users can view their own device access
CREATE POLICY "Users can view their own access"
    ON device_access FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Admins and employees can view ALL device access (for admin panel)
CREATE POLICY "Admins and employees can view all access"
    ON device_access FOR SELECT
    TO authenticated
    USING (
        public.get_user_role() IN ('admin', 'employee')
    );

-- Admins and employees can insert device access
CREATE POLICY "Admins and employees can insert device access"
    ON device_access FOR INSERT
    TO authenticated
    WITH CHECK (
        public.get_user_role() IN ('admin', 'employee')
    );

-- Admins and employees can update device access
CREATE POLICY "Admins and employees can update device access"
    ON device_access FOR UPDATE
    TO authenticated
    USING (
        public.get_user_role() IN ('admin', 'employee')
    )
    WITH CHECK (
        public.get_user_role() IN ('admin', 'employee')
    );

-- Admins and employees can delete device access
CREATE POLICY "Admins and employees can delete device access"
    ON device_access FOR DELETE
    TO authenticated
    USING (
        public.get_user_role() IN ('admin', 'employee')
    );

SELECT 'Device access RLS policies fixed!' AS status;
