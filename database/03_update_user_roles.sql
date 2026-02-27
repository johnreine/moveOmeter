-- ============================================
-- Migration 03: Update User Roles
-- ============================================
-- Purpose: Change role terminology from "caretakee" to "resident"
-- Run this after previous migrations

-- Drop old constraint
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;

-- Add new constraint with updated roles
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check
CHECK (role IN ('admin', 'employee', 'caretaker', 'resident'));

-- Update existing 'caretakee' roles to 'resident'
UPDATE user_profiles
SET role = 'resident'
WHERE role = 'caretakee';

-- Role definitions:
-- admin: System administrator (unchanged)
-- employee: Staff member with broad access (unchanged)
-- caretaker: Family member or caregiver (typically adult children) - manages devices for residents
-- resident: Person living at installedLocation being monitored (formerly "caretakee")

SELECT 'User roles updated successfully!' AS status,
       COUNT(*) FILTER (WHERE role = 'admin') as admin_count,
       COUNT(*) FILTER (WHERE role = 'employee') as employee_count,
       COUNT(*) FILTER (WHERE role = 'caretaker') as caretaker_count,
       COUNT(*) FILTER (WHERE role = 'resident') as resident_count
FROM user_profiles;
