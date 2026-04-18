-- ============================================
-- Backfill Device-Level Daily Aggregates
-- ============================================
-- Purpose: Populate daily_aggregates with device-level metrics for the last 7 days
-- This is needed for device detail pages to show daily reports

DO $$
DECLARE
  v_device RECORD;
  v_day INTEGER;
  v_target_date DATE;
  v_total_days INTEGER := 0;
  v_total_devices INTEGER := 0;
BEGIN
  RAISE NOTICE 'Starting device-level daily aggregates backfill...';
  RAISE NOTICE 'Date range: % to %', CURRENT_DATE - 6, CURRENT_DATE;
  RAISE NOTICE '';

  -- Loop through all active devices
  FOR v_device IN
    SELECT device_id
    FROM moveometers
    WHERE device_status = 'active'
    ORDER BY device_id
  LOOP
    v_total_devices := v_total_devices + 1;
    RAISE NOTICE 'Processing device: %', v_device.device_id;

    -- Calculate metrics for last 7 days
    FOR v_day IN 0..6 LOOP
      v_target_date := CURRENT_DATE - v_day;

      -- Check if data exists for this day
      IF EXISTS (
        SELECT 1 FROM mmwave_sensor_data
        WHERE device_id = v_device.device_id
          AND DATE(COALESCE(device_timestamp, created_at)) = v_target_date
      ) THEN
        -- Calculate and store metrics
        PERFORM calculate_daily_metrics(v_device.device_id, v_target_date);
        v_total_days := v_total_days + 1;
        RAISE NOTICE '  ✓ Calculated metrics for %', v_target_date;
      ELSE
        RAISE NOTICE '  - No data for %', v_target_date;
      END IF;
    END LOOP;

    RAISE NOTICE '';
  END LOOP;

  RAISE NOTICE '========================================';
  RAISE NOTICE 'Backfill complete!';
  RAISE NOTICE 'Processed % devices', v_total_devices;
  RAISE NOTICE 'Calculated % device-days of metrics', v_total_days;
  RAISE NOTICE '========================================';
END $$;

-- Verify the backfill
SELECT
  device_id,
  date,
  motion_score,
  total_active_minutes,
  first_motion_time,
  last_motion_time,
  CASE
    WHEN house_id IS NULL THEN 'device-level'
    ELSE 'house-level'
  END as record_type
FROM daily_aggregates
WHERE device_id = 'ESP32C6_001'
  AND house_id IS NULL
ORDER BY date DESC;
