-- ============================================
-- Add Test moveOmeters with Sample Data
-- ============================================
-- This script adds 3 test moveOmeters to your house with realistic sample data
-- Run this in Supabase SQL Editor

-- ============================================
-- Step 1: Get the house_id (you'll need to update this)
-- ============================================
-- First, run this query to find your house_id:
-- SELECT id, name FROM houses WHERE is_active = true;
-- Copy the UUID and replace 'YOUR_HOUSE_ID_HERE' below

DO $$
DECLARE
    v_house_id UUID;
    v_device_id_1 TEXT := 'ESP32C6_BEDROOM';
    v_device_id_2 TEXT := 'ESP32C6_BATHROOM';
    v_device_id_3 TEXT := 'ESP32C6_KITCHEN';
    v_start_date DATE := CURRENT_DATE - INTERVAL '7 days';
    v_current_hour TIMESTAMPTZ;
    v_day_offset INTEGER;
    v_hour INTEGER;
BEGIN
    -- Get the first active house (or specify your house_id)
    SELECT id INTO v_house_id
    FROM houses
    WHERE is_active = true
    LIMIT 1;

    IF v_house_id IS NULL THEN
        RAISE EXCEPTION 'No active house found. Please create a house first.';
    END IF;

    RAISE NOTICE 'Using house_id: %', v_house_id;

    -- ============================================
    -- Step 2: Insert test moveOmeters
    -- ============================================

    -- Bedroom device
    INSERT INTO moveometers (
        device_id,
        house_id,
        location_name,
        device_status,
        operational_mode,
        seated_distance_threshold_cm,
        motion_distance_threshold_cm,
        fall_time_sec,
        residence_time_sec,
        residence_switch,
        fall_sensitivity,
        fall_detection_interval_ms,
        sleep_mode_interval_ms,
        config_check_interval_ms,
        ota_check_interval_ms,
        last_seen
    ) VALUES (
        v_device_id_1,
        v_house_id,
        'Master Bedroom',
        'active',
        'fall_detection',
        100,
        150,
        5,
        30,
        true,
        3,
        20000,
        20000,
        20000,
        3600000,
        NOW() - INTERVAL '15 minutes'
    ) ON CONFLICT (device_id) DO NOTHING;

    -- Bathroom device
    INSERT INTO moveometers (
        device_id,
        house_id,
        location_name,
        device_status,
        operational_mode,
        seated_distance_threshold_cm,
        motion_distance_threshold_cm,
        fall_time_sec,
        residence_time_sec,
        residence_switch,
        fall_sensitivity,
        fall_detection_interval_ms,
        sleep_mode_interval_ms,
        config_check_interval_ms,
        ota_check_interval_ms,
        last_seen
    ) VALUES (
        v_device_id_2,
        v_house_id,
        'Master Bathroom',
        'active',
        'fall_detection',
        100,
        150,
        5,
        30,
        true,
        3,
        20000,
        20000,
        20000,
        3600000,
        NOW() - INTERVAL '5 minutes'
    ) ON CONFLICT (device_id) DO NOTHING;

    -- Kitchen device
    INSERT INTO moveometers (
        device_id,
        house_id,
        location_name,
        device_status,
        operational_mode,
        seated_distance_threshold_cm,
        motion_distance_threshold_cm,
        fall_time_sec,
        residence_time_sec,
        residence_switch,
        fall_sensitivity,
        fall_detection_interval_ms,
        sleep_mode_interval_ms,
        config_check_interval_ms,
        ota_check_interval_ms,
        last_seen
    ) VALUES (
        v_device_id_3,
        v_house_id,
        'Kitchen',
        'active',
        'fall_detection',
        100,
        150,
        5,
        30,
        true,
        3,
        20000,
        20000,
        20000,
        3600000,
        NOW() - INTERVAL '2 minutes'
    ) ON CONFLICT (device_id) DO NOTHING;

    RAISE NOTICE 'Test devices created successfully';

    -- ============================================
    -- Step 3: Generate sample sensor data for last 7 days
    -- ============================================

    -- For each day in the last 7 days
    FOR v_day_offset IN 0..6 LOOP
        -- Generate hourly data for typical activity patterns
        FOR v_hour IN 0..23 LOOP
            v_current_hour := (CURRENT_DATE - v_day_offset) + (v_hour || ' hours')::INTERVAL;

            -- Bedroom - High activity morning (6-9am) and evening (6-10pm), sleep at night
            IF v_hour BETWEEN 0 AND 5 THEN
                -- Sleeping - low movement
                INSERT INTO mmwave_sensor_data (
                    device_id, sensor_mode, device_timestamp,
                    human_existence, body_movement, motion_detected,
                    breathing_exists, respiration, heart_rate, sleep_state, sleep_quality
                )
                SELECT
                    v_device_id_1,
                    'sleep',
                    v_current_hour + (minute || ' minutes')::INTERVAL,
                    1, -- person present
                    random() * 5, -- minimal movement
                    0, -- not moving
                    1, -- breathing detected
                    14 + random() * 4, -- respiration 14-18
                    60 + random() * 10, -- heart rate 60-70
                    1, -- sleeping
                    70 + random() * 20 -- sleep quality 70-90
                FROM generate_series(0, 59, 5) AS minute;

            ELSIF v_hour BETWEEN 6 AND 9 OR v_hour BETWEEN 18 AND 22 THEN
                -- Active periods
                INSERT INTO mmwave_sensor_data (
                    device_id, sensor_mode, device_timestamp,
                    human_existence, body_movement, motion_detected, fall_state
                )
                SELECT
                    v_device_id_1,
                    'fall_detection',
                    v_current_hour + (minute || ' minutes')::INTERVAL,
                    CASE WHEN random() > 0.3 THEN 1 ELSE 0 END, -- 70% presence
                    random() * 40 + 10, -- moderate to high movement 10-50
                    CASE WHEN random() > 0.4 THEN 1 ELSE 0 END, -- 60% motion detected
                    0 -- no falls
                FROM generate_series(0, 59, 5) AS minute;
            ELSE
                -- Low activity during day
                INSERT INTO mmwave_sensor_data (
                    device_id, sensor_mode, device_timestamp,
                    human_existence, body_movement, motion_detected, fall_state
                )
                SELECT
                    v_device_id_1,
                    'fall_detection',
                    v_current_hour + (minute || ' minutes')::INTERVAL,
                    CASE WHEN random() > 0.7 THEN 1 ELSE 0 END, -- 30% presence
                    random() * 15, -- low movement 0-15
                    CASE WHEN random() > 0.8 THEN 1 ELSE 0 END, -- 20% motion
                    0
                FROM generate_series(0, 59, 10) AS minute;
            END IF;

            -- Bathroom - Burst activity patterns (morning and evening)
            IF v_hour BETWEEN 7 AND 8 OR v_hour BETWEEN 20 AND 21 THEN
                INSERT INTO mmwave_sensor_data (
                    device_id, sensor_mode, device_timestamp,
                    human_existence, body_movement, motion_detected, fall_state
                )
                SELECT
                    v_device_id_2,
                    'fall_detection',
                    v_current_hour + (minute || ' minutes')::INTERVAL,
                    CASE WHEN random() > 0.2 THEN 1 ELSE 0 END, -- 80% presence during these hours
                    random() * 50 + 20, -- high movement 20-70
                    1, -- active motion
                    0
                FROM generate_series(0, 59, 5) AS minute;
            ELSIF v_hour BETWEEN 0 AND 6 OR v_hour BETWEEN 22 AND 23 THEN
                -- No activity at night
                NULL;
            ELSE
                -- Occasional use during day
                INSERT INTO mmwave_sensor_data (
                    device_id, sensor_mode, device_timestamp,
                    human_existence, body_movement, motion_detected, fall_state
                )
                SELECT
                    v_device_id_2,
                    'fall_detection',
                    v_current_hour + (minute || ' minutes')::INTERVAL,
                    CASE WHEN random() > 0.9 THEN 1 ELSE 0 END, -- 10% presence
                    random() * 30, -- variable movement
                    CASE WHEN random() > 0.9 THEN 1 ELSE 0 END,
                    0
                FROM generate_series(0, 59, 10) AS minute
                WHERE random() > 0.7; -- Only some readings
            END IF;

            -- Kitchen - High activity meal times (7-8am, 12-1pm, 6-7pm)
            IF v_hour IN (7, 12, 18) THEN
                INSERT INTO mmwave_sensor_data (
                    device_id, sensor_mode, device_timestamp,
                    human_existence, body_movement, motion_detected, fall_state
                )
                SELECT
                    v_device_id_3,
                    'fall_detection',
                    v_current_hour + (minute || ' minutes')::INTERVAL,
                    1, -- always present during meals
                    random() * 60 + 30, -- high movement 30-90
                    1, -- active motion
                    0
                FROM generate_series(0, 59, 3) AS minute;
            ELSIF v_hour BETWEEN 9 AND 11 OR v_hour BETWEEN 14 AND 17 THEN
                -- Moderate activity between meals
                INSERT INTO mmwave_sensor_data (
                    device_id, sensor_mode, device_timestamp,
                    human_existence, body_movement, motion_detected, fall_state
                )
                SELECT
                    v_device_id_3,
                    'fall_detection',
                    v_current_hour + (minute || ' minutes')::INTERVAL,
                    CASE WHEN random() > 0.6 THEN 1 ELSE 0 END, -- 40% presence
                    random() * 25, -- moderate movement
                    CASE WHEN random() > 0.6 THEN 1 ELSE 0 END,
                    0
                FROM generate_series(0, 59, 10) AS minute;
            ELSE
                -- Low/no activity other times
                INSERT INTO mmwave_sensor_data (
                    device_id, sensor_mode, device_timestamp,
                    human_existence, body_movement, motion_detected, fall_state
                )
                SELECT
                    v_device_id_3,
                    'fall_detection',
                    v_current_hour + (minute || ' minutes')::INTERVAL,
                    0,
                    0,
                    0,
                    0
                FROM generate_series(0, 59, 15) AS minute
                WHERE random() > 0.8;
            END IF;

        END LOOP;
    END LOOP;

    RAISE NOTICE 'Sample sensor data generated for 7 days';

    -- ============================================
    -- Step 4: Calculate daily aggregates
    -- ============================================

    FOR v_day_offset IN 0..6 LOOP
        -- Calculate metrics for each device
        PERFORM calculate_daily_metrics(v_device_id_1, CURRENT_DATE - v_day_offset);
        PERFORM calculate_daily_metrics(v_device_id_2, CURRENT_DATE - v_day_offset);
        PERFORM calculate_daily_metrics(v_device_id_3, CURRENT_DATE - v_day_offset);
    END LOOP;

    RAISE NOTICE 'Daily aggregates calculated successfully';
    RAISE NOTICE 'Test data setup complete!';

END $$;

-- ============================================
-- Verification queries
-- ============================================

-- Check devices were created
SELECT device_id, location_name, device_status, house_id
FROM moveometers
WHERE device_id LIKE 'ESP32C6_%'
ORDER BY location_name;

-- Check sensor data count
SELECT
    device_id,
    COUNT(*) as data_points,
    MIN(device_timestamp) as first_reading,
    MAX(device_timestamp) as last_reading
FROM mmwave_sensor_data
WHERE device_id LIKE 'ESP32C6_%'
GROUP BY device_id
ORDER BY device_id;

-- Check daily aggregates
SELECT
    device_id,
    date,
    motion_score,
    total_active_minutes,
    first_motion_time,
    last_motion_time
FROM daily_aggregates
WHERE device_id LIKE 'ESP32C6_%'
ORDER BY device_id, date DESC
LIMIT 21; -- 7 days x 3 devices
