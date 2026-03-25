# Supabase Edge Functions Setup

This directory contains Supabase Edge Functions for the moveOmeter project.

## Functions

### check-stale-devices

Periodically checks for devices that haven't sent data recently and updates their connection status (online → stale → offline).

**Thresholds:**
- **Online**: Data within last 20 seconds
- **Stale**: Data 20-60 seconds ago
- **Offline**: No data for 60+ seconds

## Deployment

### Prerequisites

1. Install Supabase CLI:
```bash
brew install supabase/tap/supabase
# or
npm install -g supabase
```

2. Login to Supabase:
```bash
supabase login
```

3. Link to your project:
```bash
supabase link --project-ref YOUR_PROJECT_REF
```

### Deploy Edge Function

```bash
# Deploy the check-stale-devices function
supabase functions deploy check-stale-devices

# Verify deployment
supabase functions list
```

### Test the Function

```bash
# Test locally
supabase functions serve check-stale-devices

# Test deployed function
curl -X POST \
  "https://YOUR_PROJECT_REF.supabase.co/functions/v1/check-stale-devices" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

## Scheduling Options

You need to call this function every 30-60 seconds. Choose ONE option:

### Option 1: GitHub Actions (Recommended - Free)

The `.github/workflows/check-stale-devices.yml` workflow is already set up.

**Setup:**
1. Go to GitHub repository settings
2. Navigate to Secrets and Variables → Actions
3. Add these secrets:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_ANON_KEY`: Your Supabase anon/public key

The workflow will run every minute automatically.

**Note:** GitHub Actions minimum interval is 1 minute (not 30 seconds). This is acceptable for device monitoring.

### Option 2: External Cron Service (30-second intervals)

For true 30-second intervals, use an external service:

**cron-job.org (Free):**
1. Sign up at https://cron-job.org
2. Create a new cron job:
   - URL: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/check-stale-devices`
   - Interval: Every 30 seconds (or 1 minute)
   - HTTP Method: POST
   - Headers:
     - `Authorization: Bearer YOUR_ANON_KEY`
     - `Content-Type: application/json`

**EasyCron (Free tier):**
1. Sign up at https://www.easycron.com
2. Create cron job with similar settings
3. Minimum free interval: 1 minute

**UptimeRobot (Free - but 5-minute minimum):**
- Good for monitoring but too slow for device status

### Option 3: Self-Hosted Cron

If you have a server, add to crontab:

```bash
# Every minute
* * * * * curl -X POST "https://YOUR_PROJECT_REF.supabase.co/functions/v1/check-stale-devices" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

## Monitoring

### Check Function Logs

```bash
# View logs from Supabase dashboard
# Or via CLI:
supabase functions logs check-stale-devices
```

### Check Database Status

```sql
-- See recent status changes
SELECT
  device_id,
  status,
  started_at,
  ended_at,
  ROUND(duration_seconds / 60.0, 1) as duration_minutes
FROM device_status_history
ORDER BY started_at DESC
LIMIT 20;

-- See current device status
SELECT
  device_id,
  connection_status,
  seconds_since_last_data,
  connection_quality_score,
  last_data_received_at
FROM moveometers
WHERE device_status = 'active';
```

## Troubleshooting

### Function returns 500 error

Check that the database function exists:
```sql
SELECT * FROM check_stale_devices();
```

If it doesn't exist, run the migrations in `database/` directory.

### No status changes happening

1. Verify the function is being called (check logs)
2. Verify devices have `last_data_received_at` set
3. Manually run: `SELECT * FROM check_stale_devices();`

### GitHub Actions not running

1. Verify secrets are set correctly
2. Check Actions tab for error messages
3. Verify repository has Actions enabled

## Cost Considerations

**Supabase Edge Functions:**
- Free tier: 500K function invocations/month
- At 1 call per minute: ~43K calls/month (well within free tier)
- At 2 calls per minute: ~86K calls/month (still within free tier)

**GitHub Actions:**
- Free for public repositories
- Free tier: 2,000 minutes/month for private repos
- This workflow uses ~1 second per run = ~44 minutes/month

Both options are FREE for this use case.
