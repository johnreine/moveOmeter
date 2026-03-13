# Device Status Migration - Setup Guide

## Overview
This migration adds server-side device status tracking, eliminating the need for clients to calculate online/offline status.

## What Gets Created

1. **New columns in `moveometers` table:**
   - `connection_status` - 'online', 'stale', 'offline', 'unknown'
   - `connection_status_updated_at` - When status last changed
   - `seconds_since_last_data` - Seconds since last data received
   - `connection_quality_score` - 0-100 quality score
   - `last_data_received_at` - Most recent data timestamp

2. **New table `device_status_history`:**
   - Tracks all status changes over time
   - Used for analytics and debugging

3. **Database trigger:**
   - Automatically updates device status on every sensor data insert
   - Records status changes in history table

4. **Stale device checker function:**
   - Callable function to update devices that haven't sent data
   - Should be run every 30 seconds via scheduled job

## Installation Steps

### Step 1: Run Migrations in Supabase SQL Editor

Open Supabase SQL Editor and run each migration file in order:

1. **10_add_device_status_columns.sql**
2. **11_create_device_status_history.sql**
3. **12_create_device_status_trigger.sql**
4. **13_create_stale_device_checker.sql**
5. **14_backfill_device_status.sql**

**OR** copy/paste all the SQL from these files in order into one query.

### Step 2: Set Up Scheduled Job

You need to run `check_stale_devices()` every 30 seconds. Options:

#### Option A: Supabase Edge Function (Recommended)

Create a Supabase Edge Function that runs on a schedule:

```typescript
// supabase/functions/check-stale-devices/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  const { data, error } = await supabase.rpc('check_stale_devices');

  if (error) {
    console.error('Error checking stale devices:', error);
    return new Response(JSON.stringify({ error }), { status: 500 });
  }

  console.log('Checked stale devices:', data);
  return new Response(JSON.stringify({ success: true, changes: data }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
```

Then schedule it via cron (every 30 seconds):
```bash
# In your CI/CD or use a service like cron-job.org
*/30 * * * * * curl -X POST https://your-project.supabase.co/functions/v1/check-stale-devices \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

#### Option B: External Cron Service

Use a service like:
- UptimeRobot (free tier allows 5-minute intervals)
- Cron-job.org (allows custom intervals)
- GitHub Actions (scheduled workflow)

Create an API endpoint that calls the function.

#### Option C: pg_cron Extension (If Available)

If your Supabase project has pg_cron enabled:

```sql
SELECT cron.schedule(
    'check-stale-devices',
    '*/1 * * * *', -- Every minute (30s not supported by pg_cron)
    $$SELECT check_stale_devices();$$
);
```

### Step 3: Verify Installation

Run this query to check everything is working:

```sql
-- Check device status columns exist
SELECT
    device_id,
    connection_status,
    seconds_since_last_data,
    connection_quality_score,
    last_data_received_at
FROM moveometers
LIMIT 5;

-- Check status history is being recorded
SELECT
    device_id,
    status,
    started_at,
    ended_at,
    duration_seconds
FROM device_status_history
ORDER BY started_at DESC
LIMIT 10;

-- Test the stale device checker
SELECT * FROM check_stale_devices();
```

### Step 4: Test the Trigger

Insert test data and watch the status update:

```sql
-- Before: Check current status
SELECT device_id, connection_status, seconds_since_last_data
FROM moveometers
WHERE device_id = 'ESP32C6_001';

-- Insert new data
INSERT INTO mmwave_sensor_data (
    device_id,
    sensor_mode,
    device_timestamp,
    human_existence,
    body_movement
) VALUES (
    'ESP32C6_001',
    'fall_detection',
    NOW(),
    1,
    50
);

-- After: Check status updated automatically
SELECT device_id, connection_status, seconds_since_last_data
FROM moveometers
WHERE device_id = 'ESP32C6_001';

-- Check history was recorded
SELECT device_id, status, started_at, ended_at
FROM device_status_history
WHERE device_id = 'ESP32C6_001'
ORDER BY started_at DESC
LIMIT 3;
```

## Status Thresholds

- **Online**: Data received within last 20 seconds
- **Stale**: Data received 20-60 seconds ago
- **Offline**: No data for more than 60 seconds
- **Unknown**: No data ever received

## Troubleshooting

### Status not updating on data insert

1. Check trigger exists:
   ```sql
   SELECT tgname FROM pg_trigger WHERE tgname = 'trigger_update_device_status';
   ```

2. Check for errors in logs

3. Manually run the update function:
   ```sql
   SELECT update_device_status();
   ```

### Status not updating for stale devices

1. Ensure `check_stale_devices()` is being called regularly
2. Check function output:
   ```sql
   SELECT * FROM check_stale_devices();
   ```
3. Verify last_data_received_at is set:
   ```sql
   SELECT device_id, last_data_received_at FROM moveometers;
   ```

## Next Steps

After database setup is complete:
1. Test with your ESP32 device
2. Update mobile app to read status from database
3. Update web dashboard to read status from database
4. Remove all client-side status calculation logic

## Rollback

If you need to rollback these changes:

```sql
-- Drop trigger
DROP TRIGGER IF EXISTS trigger_update_device_status ON mmwave_sensor_data;

-- Drop functions
DROP FUNCTION IF EXISTS update_device_status();
DROP FUNCTION IF EXISTS check_stale_devices();

-- Drop status history table
DROP TABLE IF EXISTS device_status_history CASCADE;

-- Remove columns from moveometers
ALTER TABLE moveometers
DROP COLUMN IF EXISTS connection_status,
DROP COLUMN IF EXISTS connection_status_updated_at,
DROP COLUMN IF EXISTS seconds_since_last_data,
DROP COLUMN IF EXISTS connection_quality_score,
DROP COLUMN IF EXISTS last_data_received_at;
```
