-- ============================================
-- Migration 14: Backfill Initial Device Status
-- ============================================
-- Purpose: Initialize status for all existing devices based on their most recent data

DO $$
DECLARE
    v_device RECORD;
    v_last_data TIMESTAMPTZ;
    v_seconds_ago INTEGER;
    v_initial_status VARCHAR(20);
    v_quality_score INTEGER;
    v_updated_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'Starting device status backfill...';

    -- Loop through all devices
    FOR v_device IN
        SELECT device_id, device_status
        FROM moveometers
    LOOP
        -- Get the most recent data timestamp for this device
        SELECT COALESCE(MAX(device_timestamp), MAX(created_at))
        INTO v_last_data
        FROM mmwave_sensor_data
        WHERE device_id = v_device.device_id;

        IF v_last_data IS NULL THEN
            -- No data ever received - mark as unknown
            v_initial_status := 'unknown';
            v_quality_score := 0;
            v_seconds_ago := NULL;
        ELSE
            -- Calculate how long ago the last data was
            v_seconds_ago := EXTRACT(EPOCH FROM (NOW() - v_last_data))::INTEGER;

            -- Determine initial status
            IF v_seconds_ago <= 20 THEN
                v_initial_status := 'online';
                v_quality_score := 100;
            ELSIF v_seconds_ago <= 60 THEN
                v_initial_status := 'stale';
                v_quality_score := 70;
            ELSE
                v_initial_status := 'offline';
                v_quality_score := 0;
            END IF;
        END IF;

        -- Update the device
        UPDATE moveometers
        SET
            connection_status = v_initial_status,
            connection_status_updated_at = NOW(),
            seconds_since_last_data = COALESCE(v_seconds_ago, 0),
            last_data_received_at = v_last_data,
            connection_quality_score = v_quality_score
        WHERE device_id = v_device.device_id;

        -- Create initial status history entry
        INSERT INTO device_status_history (device_id, status, started_at)
        VALUES (v_device.device_id, v_initial_status, NOW());

        v_updated_count := v_updated_count + 1;

        RAISE NOTICE 'Device %: % (% seconds ago)',
            v_device.device_id,
            v_initial_status,
            COALESCE(v_seconds_ago, 0);
    END LOOP;

    RAISE NOTICE 'Backfill complete! Updated % devices', v_updated_count;
END $$;

-- Verify the backfill
SELECT
    device_id,
    connection_status,
    seconds_since_last_data,
    connection_quality_score,
    last_data_received_at
FROM moveometers
ORDER BY device_id;

RAISE NOTICE 'Device status backfill completed successfully!';
