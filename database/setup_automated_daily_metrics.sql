-- Setup Automated Daily Metrics Calculation
-- This script enables pg_cron and schedules automatic daily metrics calculation

-- Step 1: Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Step 2: Schedule daily metrics calculation
-- Runs every day at 6 AM UTC (1-2 AM Eastern depending on DST)
-- Calculates metrics for the previous day (yesterday)
SELECT cron.schedule(
  'calculate-daily-metrics',           -- Job name
  '0 6 * * *',                         -- Cron schedule: 6 AM UTC daily
  $$
  SELECT calculate_daily_metrics(
    'ESP32C6_001',
    (CURRENT_DATE - INTERVAL '1 day')::DATE
  );
  $$
);

-- Verify the job was created
SELECT
  jobid,
  jobname,
  schedule,
  command,
  active
FROM cron.job
WHERE jobname = 'calculate-daily-metrics';
