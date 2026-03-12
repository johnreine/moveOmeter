# Daily Metrics Automation

This directory contains SQL scripts to automate the calculation of daily metrics for moveOmeter devices.

## Overview

Daily metrics are calculated from raw sensor data and stored in the `daily_aggregates` table. These metrics include:
- Motion score (0-100)
- First/last motion times (wake/sleep indicators)
- Total active minutes
- Movement sessions
- Offline time
- Peak activity hour
- Fall count
- Data coverage percentage

## Files

### Core Functions
- **`calculate_daily_metrics_function.sql`** - Main function that calculates metrics for a specific device and date
- **`create_daily_aggregates.sql`** - Full schema for daily_aggregates table (with all optional columns)
- **`drop_and_create_daily_aggregates.sql`** - Simplified schema (core metrics only)

### Automation
- **`setup_automated_daily_metrics.sql`** - Enable pg_cron and schedule automatic daily calculation (yesterday's final metrics)
- **`setup_live_today_metrics.sql`** - Schedule frequent updates for today's in-progress metrics (every 15 minutes)
- **`manage_scheduled_jobs.sql`** - Commands for viewing, testing, and managing scheduled jobs

### Schema Updates
- **`add_missing_columns.sql`** - Add `updated_at` column
- **`add_new_metrics_columns.sql`** - Add `offline_minutes` and `peak_activity_hour` columns

## Initial Setup

### 1. Create the table
```sql
-- Run one of these (simplified version recommended):
\i drop_and_create_daily_aggregates.sql
-- OR
\i create_daily_aggregates.sql
```

### 2. Add new metric columns
```sql
\i add_new_metrics_columns.sql
\i add_missing_columns.sql
```

### 3. Create the calculation function
```sql
\i calculate_daily_metrics_function.sql
```

### 4. Backfill historical data
```sql
-- Calculate metrics for the past 7 days
SELECT calculate_daily_metrics('ESP32C6_001', '2026-03-07');
SELECT calculate_daily_metrics('ESP32C6_001', '2026-03-06');
SELECT calculate_daily_metrics('ESP32C6_001', '2026-03-05');
-- ... etc
```

### 5. Set up automated calculations

**Enable automation for yesterday's final metrics:**
```sql
\i setup_automated_daily_metrics.sql
```

**Enable live updates for today's metrics (run every 15 minutes):**
```sql
\i setup_live_today_metrics.sql
```

**Verify both jobs are running:**
```sql
SELECT jobname, schedule, active FROM cron.job
WHERE jobname IN ('calculate-daily-metrics', 'update-today-metrics');
```

## Automation Details

We run **two separate scheduled jobs** for different purposes:

### Job 1: Yesterday's Final Metrics (`calculate-daily-metrics`)
- **Schedule**: Once per day at 6:00 AM UTC (1-2 AM Eastern)
- **Purpose**: Calculate complete, finalized metrics for yesterday
- **Data**: Full 24-hour period (midnight to midnight Eastern time)
- **Use case**: Historical trends, weekly summaries, past day details

### Job 2: Today's Live Metrics (`update-today-metrics`)
- **Schedule**: Every 15 minutes throughout the day
- **Purpose**: Show "how the day is going" with current progress
- **Data**: Partial day from midnight until now
- **Use case**: "Today's Activity" section in mobile app, real-time monitoring

### Why Two Jobs?

**Yesterday's metrics** are finalized - the day is over, so we only need to calculate once.

**Today's metrics** are constantly changing as new data arrives throughout the day. Updating every 15 minutes keeps the "Today's Activity" view fresh without overwhelming the database.

### What It Does
1. Queries all sensor data from yesterday (midnight to midnight Eastern time)
2. Calculates aggregate metrics (motion score, active minutes, etc.)
3. Inserts or updates the `daily_aggregates` table
4. Stores results with proper timezone handling

### Monitoring
```sql
-- View recent job executions
SELECT * FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 10;

-- Check for failures
SELECT * FROM cron.job_run_details
WHERE status = 'failed'
ORDER BY start_time DESC;
```

## Manual Execution

### Calculate for a specific date
```sql
SELECT calculate_daily_metrics('ESP32C6_001', '2026-03-07');
```

### Calculate for yesterday (what the cron job does)
```sql
SELECT calculate_daily_metrics(
  'ESP32C6_001',
  (CURRENT_DATE - INTERVAL '1 day')::DATE
);
```

### Backfill multiple days
```sql
DO $$
BEGIN
  FOR i IN 1..30 LOOP
    PERFORM calculate_daily_metrics(
      'ESP32C6_001',
      (CURRENT_DATE - i * INTERVAL '1 day')::DATE
    );
  END LOOP;
END $$;
```

## Timezone Handling

**CRITICAL**: All timestamps in the database are stored in **UTC**, but daily boundaries are calculated in **Eastern time** (`America/New_York`).

- Database stores: `2026-03-07 13:30:00 UTC`
- Represents: `2026-03-07 08:30:00 ET` (Eastern time)
- Daily metrics for March 7 include: `2026-03-07 00:00:00 ET` to `2026-03-07 23:59:59 ET`
- Which queries as: `2026-03-07 05:00:00 UTC` to `2026-03-08 04:59:59 UTC`

### Why Eastern Time?
The user (elderly person being monitored) is located in the Eastern timezone. Daily metrics should align with their actual day (midnight to midnight in their local time), not UTC days.

## Troubleshooting

### Job isn't running
```sql
-- Check if job exists and is active
SELECT * FROM cron.job WHERE jobname = 'calculate-daily-metrics';

-- Check recent execution history
SELECT * FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'calculate-daily-metrics')
ORDER BY start_time DESC
LIMIT 5;
```

### Wrong timezone in results
Make sure the function uses `America/New_York` for day boundaries:
```sql
v_start_of_day := (p_date::DATE || ' 00:00:00')::TIMESTAMP AT TIME ZONE 'America/New_York';
```

### No data for today
This is expected! The automated job calculates **yesterday's** metrics. Today's metrics won't be available until tomorrow morning.

To see today's partial metrics, run manually:
```sql
SELECT calculate_daily_metrics('ESP32C6_001', CURRENT_DATE);
```

## Future Enhancements

- [ ] Support multiple devices (currently hardcoded to ESP32C6_001)
- [ ] Add email/Slack notifications on job failures
- [ ] Calculate weekly/monthly aggregates
- [ ] Add baseline tracking (30-day moving average)
- [ ] Implement variance detection and alerts
- [ ] Store calculation metadata (processing time, data quality flags)
