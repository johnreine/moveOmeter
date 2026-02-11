-- ============================================
-- moveOmeter Authentication & Authorization Setup
-- ============================================
-- Run this in Supabase SQL Editor
-- This sets up user roles, device access, and RLS policies

-- ============================================
-- 1. User Profiles Table
-- ============================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    role TEXT NOT NULL CHECK (role IN ('admin', 'employee', 'caretaker', 'caretakee')),
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true
);

-- Index for faster role queries
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON user_profiles(role);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);

-- ============================================
-- 2. Device Access Control
-- ============================================
CREATE TABLE IF NOT EXISTS device_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    device_id TEXT REFERENCES moveometers(device_id) ON DELETE CASCADE NOT NULL,
    access_level TEXT DEFAULT 'view' CHECK (access_level IN ('view', 'control', 'admin')),
    granted_by UUID REFERENCES user_profiles(id),
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    UNIQUE(user_id, device_id)
);

-- Indexes for faster access checks
CREATE INDEX IF NOT EXISTS idx_device_access_user ON device_access(user_id);
CREATE INDEX IF NOT EXISTS idx_device_access_device ON device_access(device_id);

-- ============================================
-- 3. Caretakee to Device Mapping
-- ============================================
-- Maps which caretakee "owns" which device
CREATE TABLE IF NOT EXISTS caretakee_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caretakee_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    device_id TEXT REFERENCES moveometers(device_id) ON DELETE CASCADE NOT NULL,
    relationship TEXT, -- e.g., "self", "parent", "spouse"
    primary_device BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(caretakee_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_caretakee_devices_user ON caretakee_devices(caretakee_id);
CREATE INDEX IF NOT EXISTS idx_caretakee_devices_device ON caretakee_devices(device_id);

-- ============================================
-- 4. Audit Log for Security
-- ============================================
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id),
    action TEXT NOT NULL, -- 'login', 'logout', 'view_data', 'modify_settings', etc.
    resource_type TEXT, -- 'device', 'user', 'annotation', etc.
    resource_id TEXT,
    ip_address INET,
    user_agent TEXT,
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action, created_at DESC);

-- ============================================
-- 5. Triggers for updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 6. Function to Check Device Access
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

    -- Caretakees can only access their own devices
    IF user_role = 'caretakee' THEN
        SELECT EXISTS(
            SELECT 1 FROM caretakee_devices
            WHERE caretakee_id = user_uuid AND device_id = dev_id
        ) INTO has_access;
        RETURN has_access;
    END IF;

    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 7. Row Level Security (RLS) Policies
-- ============================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE caretakee_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE moveometers ENABLE ROW LEVEL SECURITY;
ALTER TABLE mmwave_sensor_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE timeline_annotations ENABLE ROW LEVEL SECURITY;

-- User Profiles Policies
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
CREATE POLICY "Users can view their own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
CREATE POLICY "Users can update their own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
CREATE POLICY "Admins can view all profiles"
    ON user_profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

DROP POLICY IF EXISTS "Admins can manage all profiles" ON user_profiles;
CREATE POLICY "Admins can manage all profiles"
    ON user_profiles FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Device Access Policies
DROP POLICY IF EXISTS "Users can view their own access" ON device_access;
CREATE POLICY "Users can view their own access"
    ON device_access FOR SELECT
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can manage device access" ON device_access;
CREATE POLICY "Admins can manage device access"
    ON device_access FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee')
        )
    );

-- Caretakee Devices Policies
DROP POLICY IF EXISTS "Caretakees can view their devices" ON caretakee_devices;
CREATE POLICY "Caretakees can view their devices"
    ON caretakee_devices FOR SELECT
    USING (caretakee_id = auth.uid());

DROP POLICY IF EXISTS "Admins can manage caretakee devices" ON caretakee_devices;
CREATE POLICY "Admins can manage caretakee devices"
    ON caretakee_devices FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee')
        )
    );

-- Moveometers Table Policies
DROP POLICY IF EXISTS "Enable all operations for moveometers" ON moveometers;
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
        -- Caretakees see their own devices
        EXISTS (
            SELECT 1 FROM caretakee_devices
            WHERE caretakee_id = auth.uid() AND device_id = moveometers.device_id
        )
    );

DROP POLICY IF EXISTS "Admins can manage devices" ON moveometers;
CREATE POLICY "Admins can manage devices"
    ON moveometers FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee')
        )
    );

-- Sensor Data Policies
DROP POLICY IF EXISTS "Enable all operations for mmwave_sensor_data" ON mmwave_sensor_data;
DROP POLICY IF EXISTS "Users can view authorized device data" ON mmwave_sensor_data;
CREATE POLICY "Users can view authorized device data"
    ON mmwave_sensor_data FOR SELECT
    USING (
        user_can_access_device(auth.uid(), device_id)
    );

DROP POLICY IF EXISTS "Devices can insert their own data" ON mmwave_sensor_data;
CREATE POLICY "Devices can insert their own data"
    ON mmwave_sensor_data FOR INSERT
    WITH CHECK (true); -- Allow anon key to insert (from devices)

-- Timeline Annotations Policies
DROP POLICY IF EXISTS "Enable all operations for timeline_annotations" ON timeline_annotations;
DROP POLICY IF EXISTS "Users can view annotations for authorized devices" ON timeline_annotations;
CREATE POLICY "Users can view annotations for authorized devices"
    ON timeline_annotations FOR SELECT
    USING (
        user_can_access_device(auth.uid(), device_id)
    );

DROP POLICY IF EXISTS "Users can create annotations" ON timeline_annotations;
CREATE POLICY "Users can create annotations"
    ON timeline_annotations FOR INSERT
    WITH CHECK (
        user_can_access_device(auth.uid(), device_id)
    );

DROP POLICY IF EXISTS "Users can update their own annotations" ON timeline_annotations;
CREATE POLICY "Users can update their own annotations"
    ON timeline_annotations FOR UPDATE
    USING (created_by = auth.uid()::TEXT);

DROP POLICY IF EXISTS "Users can delete their own annotations" ON timeline_annotations;
CREATE POLICY "Users can delete their own annotations"
    ON timeline_annotations FOR DELETE
    USING (created_by = auth.uid()::TEXT);

-- Audit Log Policies
DROP POLICY IF EXISTS "Users can view their own audit logs" ON audit_log;
CREATE POLICY "Users can view their own audit logs"
    ON audit_log FOR SELECT
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "System can insert audit logs" ON audit_log;
CREATE POLICY "System can insert audit logs"
    ON audit_log FOR INSERT
    WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can view all audit logs" ON audit_log;
CREATE POLICY "Admins can view all audit logs"
    ON audit_log FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ============================================
-- 8. Create Initial Admin User (OPTIONAL)
-- ============================================
-- After running this migration, you'll need to:
-- 1. Sign up a user through Supabase Auth UI or API
-- 2. Run this to make them an admin:
--
-- INSERT INTO user_profiles (id, role, full_name, email)
-- VALUES (
--     'USER_UUID_FROM_AUTH_USERS',
--     'admin',
--     'Admin User',
--     'admin@example.com'
-- );

-- ============================================
-- 9. Enable Supabase Auth Features
-- ============================================
-- In Supabase Dashboard > Authentication > Providers:
-- ✓ Enable Email provider
-- ✓ Disable email confirmations for testing (enable for production)
--
-- In Supabase Dashboard > Authentication > Settings:
-- ✓ Enable Multi-Factor Authentication (for TOTP)
-- ✓ Enable WebAuthn (for Passkeys)

SELECT 'Authentication system setup complete!' AS status;
