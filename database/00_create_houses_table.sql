-- ============================================
-- Migration 00: Create Houses Table (Pre-requisite)
-- ============================================
-- Purpose: Create houses and house_access tables
-- Run this FIRST before other migrations (if not already created)

-- ============================================
-- 1. Houses Table
-- ============================================
CREATE TABLE IF NOT EXISTS houses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    country VARCHAR(50) DEFAULT 'USA',

    -- Visual
    thumbnail_url TEXT,  -- URL to house image/thumbnail
    description TEXT,

    -- Contact
    primary_contact_name VARCHAR(100),
    primary_contact_phone VARCHAR(20),

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- ============================================
-- 2. House Access Control
-- ============================================
-- Links users to houses they can access
CREATE TABLE IF NOT EXISTS house_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    house_id UUID REFERENCES houses(id) ON DELETE CASCADE NOT NULL,
    access_level TEXT DEFAULT 'view' CHECK (access_level IN ('view', 'manage', 'admin')),
    granted_by UUID REFERENCES user_profiles(id),
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT,
    UNIQUE(user_id, house_id)
);

-- ============================================
-- 3. Indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_houses_name ON houses(name);
CREATE INDEX IF NOT EXISTS idx_house_access_user ON house_access(user_id);
CREATE INDEX IF NOT EXISTS idx_house_access_house ON house_access(house_id);

-- ============================================
-- 4. Update Timestamp Trigger
-- ============================================
DROP TRIGGER IF EXISTS update_houses_updated_at ON houses;
CREATE TRIGGER update_houses_updated_at
    BEFORE UPDATE ON houses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 5. Add FK to moveometers table (if doesn't exist)
-- ============================================
DO $$
BEGIN
    -- Check if column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'moveometers' AND column_name = 'house_id'
    ) THEN
        ALTER TABLE moveometers ADD COLUMN house_id UUID;
    END IF;

    -- Add or update foreign key constraint
    ALTER TABLE moveometers DROP CONSTRAINT IF EXISTS fk_moveometers_house_id;
    ALTER TABLE moveometers ADD CONSTRAINT fk_moveometers_house_id
        FOREIGN KEY (house_id) REFERENCES houses(id) ON DELETE SET NULL;

    RAISE NOTICE 'house_id column and FK added to moveometers';
END $$;

-- ============================================
-- 6. Row Level Security Policies
-- ============================================
ALTER TABLE houses ENABLE ROW LEVEL SECURITY;
ALTER TABLE house_access ENABLE ROW LEVEL SECURITY;

-- Users can view houses they have access to
DROP POLICY IF EXISTS "Users can view authorized houses" ON houses;

-- Create policy based on which table exists (caretakee_devices or resident_devices)
DO $$
DECLARE
    policy_sql TEXT;
BEGIN
    -- Check which table exists
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'resident_devices') THEN
        -- Use resident_devices (after migration 04)
        policy_sql := '
        CREATE POLICY "Users can view authorized houses"
            ON houses FOR SELECT
            USING (
                EXISTS (
                    SELECT 1 FROM user_profiles
                    WHERE id = auth.uid() AND role IN (''admin'', ''employee'')
                )
                OR
                EXISTS (
                    SELECT 1 FROM house_access
                    WHERE user_id = auth.uid() AND house_id = houses.id
                )
                OR
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
            )';
    ELSIF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'caretakee_devices') THEN
        -- Use caretakee_devices (before migration 04)
        policy_sql := '
        CREATE POLICY "Users can view authorized houses"
            ON houses FOR SELECT
            USING (
                EXISTS (
                    SELECT 1 FROM user_profiles
                    WHERE id = auth.uid() AND role IN (''admin'', ''employee'')
                )
                OR
                EXISTS (
                    SELECT 1 FROM house_access
                    WHERE user_id = auth.uid() AND house_id = houses.id
                )
                OR
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
                            SELECT 1 FROM caretakee_devices cd
                            WHERE cd.caretakee_id = auth.uid() AND cd.device_id = m.device_id
                        )
                    )
                )
            )';
    ELSE
        -- Neither table exists, simpler policy
        policy_sql := '
        CREATE POLICY "Users can view authorized houses"
            ON houses FOR SELECT
            USING (
                EXISTS (
                    SELECT 1 FROM user_profiles
                    WHERE id = auth.uid() AND role IN (''admin'', ''employee'')
                )
                OR
                EXISTS (
                    SELECT 1 FROM house_access
                    WHERE user_id = auth.uid() AND house_id = houses.id
                )
                OR
                EXISTS (
                    SELECT 1 FROM moveometers m
                    WHERE m.house_id = houses.id
                    AND EXISTS (
                        SELECT 1 FROM device_access da
                        WHERE da.user_id = auth.uid() AND da.device_id = m.device_id
                    )
                )
            )';
    END IF;

    EXECUTE policy_sql;
    RAISE NOTICE 'Houses RLS policy created';
END $$;

-- Admins can manage houses
DROP POLICY IF EXISTS "Admins can manage houses" ON houses;
CREATE POLICY "Admins can manage houses"
    ON houses FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee')
        )
    );

-- Users can view their own house access
DROP POLICY IF EXISTS "Users can view their house access" ON house_access;
CREATE POLICY "Users can view their house access"
    ON house_access FOR SELECT
    USING (user_id = auth.uid());

-- Admins can manage house access
DROP POLICY IF EXISTS "Admins can manage house access" ON house_access;
CREATE POLICY "Admins can manage house access"
    ON house_access FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role IN ('admin', 'employee')
        )
    );

-- ============================================
-- 7. Sample Data
-- ============================================
-- Create a sample house for testing
DO $$
DECLARE
    sample_house_id UUID;
BEGIN
    -- Insert sample house
    INSERT INTO houses (name, address, city, state, zip_code, thumbnail_url, description)
    VALUES (
        'Grandma''s House',
        '123 Main Street',
        'San Francisco',
        'CA',
        '94102',
        'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400',
        'Primary residence with living room monitoring'
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO sample_house_id;

    -- Update existing device to link to this house
    IF sample_house_id IS NOT NULL THEN
        UPDATE moveometers
        SET house_id = sample_house_id
        WHERE device_id = 'ESP32C6_001' AND house_id IS NULL;
    END IF;
END $$;

SELECT 'Houses table created successfully!' AS status,
       COUNT(*) as total_houses
FROM houses;
