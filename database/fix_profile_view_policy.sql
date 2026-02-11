-- ============================================
-- Fix User Profile View Policy - Avoid Circular Reference
-- ============================================
-- This fixes the 500 error on login caused by circular RLS policy checks

-- ============================================
-- 1. Create helper function to check user role (SECURITY DEFINER)
-- ============================================

-- This function bypasses RLS to check the current user's role
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS TEXT AS $$
BEGIN
    RETURN (SELECT role FROM public.user_profiles WHERE id = auth.uid() LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================
-- 2. Drop ALL existing user_profiles policies
-- ============================================

DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins and employees can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can manage all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins and employees can manage all profiles" ON user_profiles;

-- ============================================
-- 3. Recreate policies using the helper function
-- ============================================

-- Users can ALWAYS view their own profile (critical for login)
CREATE POLICY "Users can view their own profile"
    ON user_profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

-- Admins and employees can view all profiles (using helper function)
CREATE POLICY "Admins and employees can view all profiles"
    ON user_profiles FOR SELECT
    TO authenticated
    USING (
        auth.user_role() IN ('admin', 'employee')
    );

-- Users can update their own profile
CREATE POLICY "Users can update their own profile"
    ON user_profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id);

-- Admins and employees can update all profiles
CREATE POLICY "Admins and employees can update all profiles"
    ON user_profiles FOR UPDATE
    TO authenticated
    USING (
        auth.user_role() IN ('admin', 'employee')
    )
    WITH CHECK (
        auth.user_role() IN ('admin', 'employee')
    );

-- Admins and employees can insert profiles (for creating users)
CREATE POLICY "Admins and employees can insert profiles"
    ON user_profiles FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.user_role() IN ('admin', 'employee')
    );

-- Admins and employees can delete profiles
CREATE POLICY "Admins and employees can delete profiles"
    ON user_profiles FOR DELETE
    TO authenticated
    USING (
        auth.user_role() IN ('admin', 'employee')
    );

SELECT 'User profile policies fixed with helper function!' AS status;
