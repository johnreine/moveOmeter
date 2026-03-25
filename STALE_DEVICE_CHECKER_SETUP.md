# Stale Device Checker - Quick Start Guide

This guide will help you set up automatic device status monitoring so offline devices are detected within 60 seconds.

## What This Does

When an ESP32 device loses internet connection, the server needs to detect it and update the status:
- **0-20 seconds**: Status remains "online" (normal delay)
- **20-60 seconds**: Status changes to "stale" (connection degrading)
- **60+ seconds**: Status changes to "offline" (connection lost)

Without this checker running, devices stay showing "online" forever (like what happened on March 17).

## Quick Setup (Recommended: GitHub Actions)

This is **FREE** and requires no external services.

### Step 1: Deploy the Edge Function

```bash
# Install Supabase CLI if you haven't already
brew install supabase/tap/supabase
# OR: npm install -g supabase

# Login to Supabase
supabase login

# Link to your project (find project ref in Supabase dashboard URL)
supabase link --project-ref YOUR_PROJECT_REF

# Deploy the function
supabase functions deploy check-stale-devices
```

### Step 2: Add GitHub Secrets

1. Go to your GitHub repository
2. Click Settings → Secrets and variables → Actions
3. Add two secrets:
   - **SUPABASE_URL**: `https://nrisopysitetqycvwxsq.supabase.co` (or your URL)
   - **SUPABASE_ANON_KEY**: Your Supabase anon key (from Supabase dashboard)

### Step 3: Push to GitHub

```bash
git add .
git commit -m "Add stale device checker edge function and workflow"
git push
```

The GitHub Action will automatically start running every minute.

### Step 4: Verify It's Working

After a few minutes:

1. **Check GitHub Actions:**
   - Go to repository → Actions tab
   - See "Check Stale Devices" workflow running

2. **Check Supabase Logs:**
   ```bash
   supabase functions logs check-stale-devices
   ```

3. **Check Database:**
   ```sql
   -- See recent status changes
   SELECT
     device_id,
     status,
     started_at,
     ended_at
   FROM device_status_history
   ORDER BY started_at DESC
   LIMIT 10;
   ```

## Alternative Setup: External Cron (30-second intervals)

If you want 30-second intervals instead of 1-minute:

### Option A: cron-job.org (Free)

1. Sign up at https://cron-job.org
2. Create new cron job:
   - **Title**: Check Stale Devices
   - **URL**: `https://nrisopysitetqycvwxsq.supabase.co/functions/v1/check-stale-devices`
   - **Interval**: Every 30 seconds (or 1 minute)
   - **HTTP Method**: POST
   - **Request Headers**:
     ```
     Authorization: Bearer YOUR_ANON_KEY
     Content-Type: application/json
     ```

### Option B: EasyCron (Free)

1. Sign up at https://www.easycron.com
2. Similar setup to cron-job.org
3. Free tier allows 1-minute intervals

## Testing Locally

Before deploying, test the function locally:

```bash
# Create .env.local file
cp supabase/functions/.env.example supabase/functions/.env.local

# Edit .env.local and add your Supabase credentials
nano supabase/functions/.env.local

# Run local test
./supabase/functions/test-local.sh

# In another terminal, call the function
curl -X POST http://localhost:54321/functions/v1/check-stale-devices \
  -H "Content-Type: application/json"
```

## Monitoring

### View Status Changes

```sql
-- Current device status
SELECT
  device_id,
  connection_status,
  seconds_since_last_data,
  last_data_received_at
FROM moveometers;

-- Recent status transitions
SELECT
  device_id,
  status,
  started_at,
  ended_at,
  ROUND(duration_seconds / 3600.0, 2) as duration_hours
FROM device_status_history
ORDER BY started_at DESC
LIMIT 20;
```

### Check Function Health

```bash
# View edge function logs
supabase functions logs check-stale-devices --tail

# Manual function call to test
curl -X POST \
  "https://nrisopysitetqycvwxsq.supabase.co/functions/v1/check-stale-devices" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Cost

Both options are **FREE**:

- **GitHub Actions**: 2,000 minutes/month free (this uses ~44 minutes/month)
- **Supabase Edge Functions**: 500K invocations/month free (this uses ~43K/month)
- **cron-job.org**: Free for basic cron jobs

## Troubleshooting

### "Function not found" error

Deploy the function first:
```bash
supabase functions deploy check-stale-devices
```

### "Database function not found" error

Run the database migrations:
```bash
# Run the SQL files in database/ directory in Supabase SQL Editor
# Specifically: 13_create_stale_device_checker.sql
```

### GitHub Action not running

1. Check repository has Actions enabled (Settings → Actions)
2. Verify secrets are set correctly
3. Check Actions tab for error logs

### No status changes showing

1. Verify devices have sent data: `SELECT device_id, last_data_received_at FROM moveometers;`
2. Manually run the function: `SELECT * FROM check_stale_devices();`
3. Check edge function logs for errors

## What's Next

Once this is running:
- ✅ Devices will automatically show "offline" within 60 seconds of losing connection
- ✅ Status history will track all connection state changes
- ✅ Your dashboard and mobile app will show accurate real-time status
- ✅ No more devices stuck showing "online" for days!

For more details, see `supabase/functions/SETUP.md`
