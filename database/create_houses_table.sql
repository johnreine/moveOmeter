-- ============================================
-- Houses Table for moveOmeter
-- ============================================
-- Creates table for managing houses/locations where moveOmeters are installed

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
CREATE TRIGGER update_houses_updated_at
    BEFORE UPDATE ON houses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 5. Add FK to moveometers table
-- ============================================
-- Update the moveometers table to add proper foreign key
ALTER TABLE moveometers
DROP CONSTRAINT IF EXISTS fk_moveometers_house_id;

ALTER TABLE moveometers
ADD CONSTRAINT fk_moveometers_house_id
FOREIGN KEY (house_id) REFERENCES houses(id) ON DELETE SET NULL;

-- ============================================
-- 6. Row Level Security Policies
-- ============================================
ALTER TABLE houses ENABLE ROW LEVEL SECURITY;
ALTER TABLE house_access ENABLE ROW LEVEL SECURITY;

-- Users can view houses they have access to
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
                    SELECT 1 FROM caretakee_devices cd
                    WHERE cd.caretakee_id = auth.uid() AND cd.device_id = m.device_id
                )
            )
        )
    );

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
    UPDATE moveometers
    SET house_id = sample_house_id
    WHERE device_id = 'ESP32C6_001' AND sample_house_id IS NOT NULL;
END $$;

SELECT 'Houses table created successfully!' AS status;
