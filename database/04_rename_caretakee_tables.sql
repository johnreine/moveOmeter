-- ============================================
-- Migration 04: Rename Caretakee Tables
-- ============================================
-- Purpose: Update table and column names for clarity (caretakee → resident)
-- Run this after 03_update_user_roles.sql

-- Check if old table exists
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'caretakee_devices') THEN
        -- Rename caretakee_devices to resident_devices
        ALTER TABLE caretakee_devices RENAME TO resident_devices;

        -- Rename column
        ALTER TABLE resident_devices RENAME COLUMN caretakee_id TO resident_id;

        -- Update index names
        ALTER INDEX IF EXISTS idx_caretakee_devices_user RENAME TO idx_resident_devices_user;
        ALTER INDEX IF EXISTS idx_caretakee_devices_device RENAME TO idx_resident_devices_device;

        RAISE NOTICE 'Table caretakee_devices renamed to resident_devices';
    ELSE
        RAISE NOTICE 'Table caretakee_devices does not exist (already renamed or not created yet)';
    END IF;
END $$;

-- Verify the rename
SELECT 'Caretakee tables renamed successfully!' AS status,
       COUNT(*) as total_resident_device_mappings
FROM resident_devices;
