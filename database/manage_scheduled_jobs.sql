-- Manage Scheduled Jobs (pg_cron)
-- Commands for viewing, testing, and managing automated daily metrics calculation

-- ============================================================
-- VIEW SCHEDULED JOBS
-- ============================================================

-- List all scheduled jobs
SELECT
  jobid,
  jobname,
  schedule,
  command,
  active,
  nodename,
  nodeport
FROM cron.job
ORDER BY jobname;

-- View job execution history (last 20 runs)
SELECT
  jobid,
  runid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 20;

-- View only failed job runs
SELECT
  jobid,
  runid,
  command,
  status,
  return_message,
  start_time
FROM cron.job_run_details
WHERE status = 'failed'
ORDER BY start_time DESC
LIMIT 10;


-- ============================================================
-- MANAGE JOBS
-- ============================================================

-- Unschedule the daily metrics job
SELECT cron.unschedule('calculate-daily-metrics');

-- Re-schedule with a different time (example: 7 AM UTC instead of 6 AM)
SELECT cron.schedule(
  'calculate-daily-metrics',
  '0 7 * * *',  -- 7 AM UTC daily
  $$
  SELECT calculate_daily_metrics(
    'ESP32C6_001',
    (CURRENT_DATE - INTERVAL '1 day')::DATE
  );
  $$
);

-- Temporarily disable a job (set active = false)
UPDATE cron.job
SET active = false
WHERE jobname = 'calculate-daily-metrics';

-- Re-enable a job
UPDATE cron.job
SET active = true
WHERE jobname = 'calculate-daily-metrics';


-- ============================================================
-- TESTING
-- ============================================================

-- Create a test job that runs every minute (for testing)
SELECT cron.schedule(
  'test-metrics-now',
  '* * * * *',  -- Every minute
  $$
  SELECT calculate_daily_metrics(
    'ESP32C6_001',
    (CURRENT_DATE - INTERVAL '1 day')::DATE
  );
  $$
);

-- Remove the test job after testing
SELECT cron.unschedule('test-metrics-now');


-- ============================================================
-- MANUAL EXECUTION
-- ============================================================

-- Manually run calculation for yesterday (same as what cron does)
SELECT calculate_daily_metrics(
  'ESP32C6_001',
  (CURRENT_DATE - INTERVAL '1 day')::DATE
);

-- Manually run for a specific date
SELECT calculate_daily_metrics('ESP32C6_001', '2026-03-07');

-- Backfill last 7 days
DO $$
BEGIN
  FOR i IN 1..7 LOOP
    PERFORM calculate_daily_metrics(
      'ESP32C6_001',
      (CURRENT_DATE - i * INTERVAL '1 day')::DATE
    );
  END LOOP;
END $$;


-- ============================================================
-- CRON SCHEDULE REFERENCE
-- ============================================================

-- Format: * * * * *
--         │ │ │ │ │
--         │ │ │ │ └─── Day of week (0-7, Sunday = 0 or 7)
--         │ │ │ └───── Month (1-12)
--         │ │ └─────── Day of month (1-31)
--         │ └───────── Hour (0-23)
--         └─────────── Minute (0-59)

-- Examples:
-- '0 6 * * *'     - Every day at 6:00 AM UTC
-- '*/15 * * * *'  - Every 15 minutes
-- '0 */2 * * *'   - Every 2 hours
-- '0 0 * * 0'     - Every Sunday at midnight UTC
-- '30 3 1 * *'    - 3:30 AM on the 1st of every month
