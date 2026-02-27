-- ============================================
-- Migration 06: Create installedLocation View
-- ============================================
-- Purpose: Create semantic view for houses table
-- Run this after previous migrations

-- Create view for installedLocations
CREATE OR REPLACE VIEW installed_locations AS
SELECT
    id as location_id,
    name as location_name,
    address,
    city,
    state,
    zip_code,
    country,
    thumbnail_url as location_image,
    description,
    primary_contact_name,
    primary_contact_phone,
    created_at,
    updated_at,
    is_active
FROM houses;

-- Note: Keep "houses" as the actual table name for backward compatibility
-- Use "installed_locations" view in application code for semantic clarity

-- Grant permissions to view
GRANT SELECT ON installed_locations TO authenticated;
GRANT SELECT ON installed_locations TO anon;

SELECT 'installedLocation view created successfully!' AS status,
       COUNT(*) as total_locations
FROM installed_locations;
