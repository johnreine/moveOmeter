-- ============================================
-- Verification Queries for Migrations
-- ============================================
-- Run these to verify all migrations completed successfully

-- 1. Check device types
SELECT 'Device Types:' as check_name;
SELECT * FROM device_types;
-- Expected: Should show 'moveometer' type

-- 2. Check moveometers have device_type_id
SELECT 'Moveometers with Device Type:' as check_name;
SELECT device_id, device_type_id, location_name FROM moveometers LIMIT 5;
-- Expected: All should have device_type_id UUIDs

-- 3. Check user roles (should be resident, not caretakee)
SELECT 'User Role Counts:' as check_name;
SELECT role, COUNT(*) as count FROM user_profiles GROUP BY role ORDER BY role;
-- Expected: admin, employee, caretaker, resident (NO caretakee)

-- 4. Check table rename (resident_devices should exist)
SELECT 'Resident Devices Table:' as check_name;
SELECT COUNT(*) as total_mappings FROM resident_devices;
-- Expected: Should work (table exists)

-- 5. Check houses table exists
SELECT 'Houses:' as check_name;
SELECT id, name, city, state FROM houses LIMIT 5;
-- Expected: Should show houses including 'Grandma''s House'

-- 6. Check installed_locations view
SELECT 'Installed Locations View:' as check_name;
SELECT location_id, location_name, city, state FROM installed_locations LIMIT 5;
-- Expected: Should show same data as houses with renamed columns

-- 7. Check daily_aggregates table exists
SELECT 'Daily Aggregates Table:' as check_name;
SELECT COUNT(*) as aggregate_count FROM daily_aggregates;
-- Expected: May be 0 (not backfilled yet) or >0 if backfilled

-- 8. Check RLS policies updated
SELECT 'RLS Policies:' as check_name;
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('resident_devices', 'houses', 'moveometers', 'daily_aggregates')
ORDER BY tablename, policyname;
-- Expected: Should show policies for all tables

SELECT '✅ All verification checks complete!' as status;
