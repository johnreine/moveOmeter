-- ============================================
-- Run All Device Status Migrations
-- ============================================
-- This script runs all migrations to add server-side device status tracking
-- Run this in Supabase SQL Editor

\echo '================================================'
\echo 'Device Status Migration - Phase 1'
\echo '================================================'
\echo ''

-- Step 1: Add status columns to moveometers table
\echo 'Step 1: Adding device status columns...'
\ir 10_add_device_status_columns.sql
\echo ''

-- Step 2: Create status history table
\echo 'Step 2: Creating device status history table...'
\ir 11_create_device_status_history.sql
\echo ''

-- Step 3: Create status update trigger
\echo 'Step 3: Creating device status update trigger...'
\ir 12_create_device_status_trigger.sql
\echo ''

-- Step 4: Create stale device checker function
\echo 'Step 4: Creating stale device checker function...'
\ir 13_create_stale_device_checker.sql
\echo ''

-- Step 5: Backfill initial status for existing devices
\echo 'Step 5: Backfilling initial device status...'
\ir 14_backfill_device_status.sql
\echo ''

\echo '================================================'
\echo 'Migration Complete!'
\echo '================================================'
\echo ''
\echo 'Next steps:'
\echo '1. Verify device status in moveometers table'
\echo '2. Check device_status_history table for initial entries'
\echo '3. Test by inserting sensor data and watching status update'
\echo '4. Set up scheduled job to call check_stale_devices() every 30s'
\echo ''
\echo 'To test the trigger:'
\echo '  INSERT INTO mmwave_sensor_data (device_id, sensor_mode, ...) VALUES (...);'
\echo ''
\echo 'To manually check for stale devices:'
\echo '  SELECT * FROM check_stale_devices();'
\echo ''
