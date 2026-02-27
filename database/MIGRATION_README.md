# moveOmeter Database Migrations

## Overview

These migrations implement Stage 1 (Database Schema Refactor) and Stage 2 (Daily Aggregation) of the moveOmeter enhancement plan.

## Changes Summary

### Stage 1: Schema Refactor
1. **Device Types**: Generalizes from "moveometers" to "devices" with device types
2. **Role Updates**: Changes "caretakee" to "resident" for clarity
3. **Table Renames**: Updates caretakee_devices → resident_devices
4. **RLS Updates**: Updates all security policies for new roles
5. **installedLocation View**: Creates semantic view for houses table

### Stage 2: Daily Aggregation
6. **Daily Aggregates Table**: Pre-computes hourly statistics for fast retrieval
7. **Aggregation Function**: Generates daily summaries from raw sensor data
8. **3600x Performance**: Reduces 86,400 data points (24h × 1/sec) to 24 hourly aggregates

## Migration Files (Run in Order)

| File | Purpose | Breaking Changes |
|------|---------|------------------|
| `00_create_houses_table.sql` | **PRE-REQUISITE**: Create houses & house_access tables | No |
| `01_create_device_types.sql` | Create device types table | No |
| `02_add_device_type_to_moveometers.sql` | Link moveometers to device types | No |
| `03_update_user_roles.sql` | Update role names (caretakee → resident) | ⚠️ Yes - Role names |
| `04_rename_caretakee_tables.sql` | Rename tables for clarity | ⚠️ Yes - Table names |
| `05_update_rls_policies.sql` | Update security policies | No |
| `06_create_installed_locations_view.sql` | Create semantic view | No |
| `07_create_daily_aggregates.sql` | Create aggregates table & function | No |

**IMPORTANT**: If you don't have the `houses` table yet, run `00_create_houses_table.sql` FIRST!

## How to Run Migrations

### Option 1: Run Individually (Recommended)

1. Go to Supabase Dashboard → SQL Editor
2. Copy contents of `01_create_device_types.sql`
3. Click **RUN**
4. Verify success message
5. Repeat for files 02-07 in order

### Option 2: Run All at Once

1. Open `RUN_MIGRATIONS_IN_ORDER.sql`
2. Copy the entire file
3. Paste into Supabase SQL Editor
4. Click **RUN**
5. Review output for any errors

## Verification Steps

After running all migrations, verify:

```sql
-- Check device types
SELECT * FROM device_types;
-- Should show: moveometer

-- Check moveometers have device_type_id
SELECT device_id, device_type_id FROM moveometers LIMIT 5;
-- All should have UUIDs

-- Check user roles
SELECT role, COUNT(*) FROM user_profiles GROUP BY role;
-- Should show: admin, employee, caretaker, resident (no caretakee)

-- Check table rename
SELECT * FROM resident_devices LIMIT 5;
-- Should work (old caretakee_devices table renamed)

-- Check installed_locations view
SELECT * FROM installed_locations LIMIT 5;
-- Should show houses with semantic column names

-- Check daily_aggregates table
SELECT * FROM daily_aggregates LIMIT 5;
-- Should exist (may be empty until backfill)
```

## Backfilling Daily Aggregates

After migration 07, backfill historical data:

```sql
-- Backfill last 30 days for your device
DO $$
DECLARE
    day_offset INTEGER;
    target_device TEXT := 'ESP32C6_001';  -- Change to your device_id
BEGIN
    FOR day_offset IN 0..29 LOOP
        RAISE NOTICE 'Processing day %...', day_offset;
        PERFORM generate_daily_aggregates(
            target_device,
            CURRENT_DATE - day_offset
        );
    END LOOP;
    RAISE NOTICE 'Backfill complete!';
END $$;

-- Verify backfill
SELECT date, COUNT(*) as hours_aggregated
FROM daily_aggregates
WHERE device_id = 'ESP32C6_001'
GROUP BY date
ORDER BY date DESC
LIMIT 7;
```

## Rolling Back Changes

If you need to rollback:

```sql
-- Rollback Migration 07
DROP TABLE IF EXISTS daily_aggregates CASCADE;
DROP FUNCTION IF EXISTS generate_daily_aggregates(TEXT, DATE);

-- Rollback Migration 06
DROP VIEW IF EXISTS installed_locations;

-- Rollback Migration 05
-- (RLS policies can be re-run with old names)

-- Rollback Migration 04
ALTER TABLE IF EXISTS resident_devices RENAME TO caretakee_devices;
ALTER TABLE IF EXISTS caretakee_devices RENAME COLUMN resident_id TO caretakee_id;

-- Rollback Migration 03
UPDATE user_profiles SET role = 'caretakee' WHERE role = 'resident';
ALTER TABLE user_profiles DROP CONSTRAINT user_profiles_role_check;
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check
CHECK (role IN ('admin', 'employee', 'caretaker', 'caretakee'));

-- Rollback Migration 02
ALTER TABLE moveometers DROP COLUMN IF EXISTS device_type_id;

-- Rollback Migration 01
DROP TABLE IF EXISTS device_types CASCADE;
```

## Breaking Changes & Migration Notes

### Application Code Updates Required

After running these migrations, update application code:

1. **Role Names**: Change `caretakee` → `resident` in all queries
2. **Table Names**: Change `caretakee_devices` → `resident_devices`
3. **View Usage**: Optionally use `installed_locations` view instead of `houses` table

### Backward Compatibility

- **Table Names**: `moveometers` and `houses` remain unchanged (backward compatible)
- **Views**: New `installed_locations` view added for semantic clarity
- **Role Names**: ⚠️ NOT backward compatible - all references must update

### Web Dashboard Compatibility

The web dashboard will continue to work without changes because:
- Table names (`moveometers`, `houses`) unchanged
- RLS policies updated to support new role names
- Views are additive (don't break existing queries)

## Performance Impact

### Daily Aggregates Benefits

- **Query Speed**: 100ms vs several seconds for 24-hour data
- **Data Reduction**: 86,400 points → 24 aggregates (3600x smaller)
- **Network Transfer**: Minimal data sent to client
- **Mobile Friendly**: Fast loading on slow connections

### Index Performance

New indexes added:
- `idx_moveometers_device_type` - Fast device type queries
- `idx_daily_aggregates_device_date` - Fast aggregate lookups
- `idx_daily_aggregates_device_hour` - Fast hourly queries

## Scheduled Aggregation (Future)

Set up automated daily aggregation with pg_cron or external scheduler:

```sql
-- Run daily at 1 AM to aggregate previous day
SELECT generate_daily_aggregates('ESP32C6_001', CURRENT_DATE - INTERVAL '1 day');
```

Or use Supabase Edge Functions for scheduled execution.

## Support

If you encounter issues:

1. Check Supabase logs for detailed error messages
2. Verify all migrations ran in order (01-07)
3. Ensure `update_updated_at_column()` function exists (from setup_authentication.sql)
4. Check that `user_can_access_device()` function was created successfully

## Next Steps

After completing Stage 1 migrations:

1. ✅ Run migrations 01-06 in Supabase
2. ✅ Verify with SELECT queries
3. ✅ Run migration 07 for daily aggregates
4. ✅ Backfill 30 days of historical data
5. → Proceed to Stage 3: Flutter app updates
