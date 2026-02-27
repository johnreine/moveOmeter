-- ============================================
-- moveOmeter Database Migrations
-- ============================================
-- Run these migrations in Supabase SQL Editor
-- Execute them in ORDER (01 through 07)

-- ============================================
-- STAGE 1: Database Schema Refactor
-- ============================================

-- Migration 01: Create device_types table
-- Purpose: Generalize from "moveometers" to "devices" with device types
\i 01_create_device_types.sql

-- Migration 02: Add device_type_id to moveometers
-- Purpose: Link existing moveometers to device_types
\i 02_add_device_type_to_moveometers.sql

-- Migration 03: Update user roles
-- Purpose: Change "caretakee" to "resident"
\i 03_update_user_roles.sql

-- Migration 04: Rename caretakee tables
-- Purpose: Update table names for clarity
\i 04_rename_caretakee_tables.sql

-- Migration 05: Update RLS policies
-- Purpose: Update policies to use new role names
\i 05_update_rls_policies.sql

-- Migration 06: Create installedLocation view
-- Purpose: Semantic view for houses table
\i 06_create_installed_locations_view.sql

-- ============================================
-- STAGE 2: Daily Data Aggregation
-- ============================================

-- Migration 07: Create daily_aggregates table
-- Purpose: Pre-compute daily statistics for fast retrieval
\i 07_create_daily_aggregates.sql

-- ============================================
-- MANUAL STEPS IN SUPABASE SQL EDITOR:
-- ============================================
-- Since Supabase SQL Editor doesn't support \i (include) commands,
-- you need to copy and paste each migration file's contents
-- in the order listed above.
--
-- OR run this combined file with all migrations:
-- Copy the ENTIRE contents of each migration file below this line
-- and run it as one large SQL script.

SELECT 'All migrations ready to run!' AS status;
SELECT 'Run each migration file (01-07) in order in Supabase SQL Editor' AS instructions;
