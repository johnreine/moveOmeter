-- ============================================
-- Backfill Hourly Aggregates for Last 7 Days
-- ============================================
-- Purpose: Generate hourly aggregates for all active devices for the last 7 days

DO $$
DECLARE
  v_device RECORD;
  v_day INTEGER;
  v_target_date DATE;
  v_hours_generated INTEGER;
  v_total_hours INTEGER := 0;
BEGIN
  RAISE NOTICE 'Backfilling hourly aggregates for last 7 days...';
  RAISE NOTICE '';

  -- Loop through all active devices
  FOR v_device IN
    SELECT device_id FROM moveometers WHERE device_status = 'active'
  LOOP
    RAISE NOTICE 'Processing device: %', v_device.device_id;

    -- Generate hourly aggregates for last 7 days
    FOR v_day IN 0..6 LOOP
      v_target_date := CURRENT_DATE - v_day;

      -- Check if data exists for this day
      IF EXISTS (
        SELECT 1 FROM mmwave_sensor_data
        WHERE device_id = v_device.device_id
          AND DATE(COALESCE(device_timestamp, created_at)) = v_target_date
      ) THEN
        -- Generate hourly aggregates
        PERFORM generate_hourly_aggregates(v_device.device_id, v_target_date);

        -- Count how many hours were generated
        SELECT COUNT(*) INTO v_hours_generated
        FROM daily_aggregates
        WHERE device_id = v_device.device_id
          AND date = v_target_date
          AND hour IS NOT NULL;

        v_total_hours := v_total_hours + v_hours_generated;
        RAISE NOTICE '  ✓ % - Generated % hours', v_target_date, v_hours_generated;
      ELSE
        RAISE NOTICE '  - % - No data', v_target_date;
      END IF;
    END LOOP;

    RAISE NOTICE '';
  END LOOP;

  RAISE NOTICE '========================================';
  RAISE NOTICE 'Backfill complete!';
  RAISE NOTICE 'Total hours generated: %', v_total_hours;
  RAISE NOTICE '========================================';
END $$;

-- Verify: Show hourly data counts for last 7 days
SELECT
  date,
  COUNT(*) as hours_with_data,
  MIN(hour) as first_hour,
  MAX(hour) as last_hour
FROM daily_aggregates
WHERE device_id = 'ESP32C6_001'
  AND hour IS NOT NULL
  AND date >= CURRENT_DATE - 6
GROUP BY date
ORDER BY date DESC;
