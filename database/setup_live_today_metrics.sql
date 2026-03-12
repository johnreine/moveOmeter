-- Setup Live "Today's Activity" Updates
-- This job runs every 15 minutes to update today's partial metrics
-- Shows "how the day is going" with current progress

-- Schedule job to update TODAY's metrics every 15 minutes
SELECT cron.schedule(
  'update-today-metrics',              -- Job name
  '*/15 * * * *',                      -- Every 15 minutes
  $$
  SELECT calculate_daily_metrics(
    'ESP32C6_001',
    CURRENT_DATE                       -- Today (not yesterday)
  );
  $$
);

-- Verify both jobs exist
SELECT
  jobid,
  jobname,
  schedule,
  command,
  active
FROM cron.job
WHERE jobname IN ('calculate-daily-metrics', 'update-today-metrics')
ORDER BY jobname;

-- Expected result:
-- Job 1: calculate-daily-metrics   | 0 6 * * *    | Runs at 6 AM for yesterday
-- Job 2: update-today-metrics      | */15 * * * * | Runs every 15 min for today
