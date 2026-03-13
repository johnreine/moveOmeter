-- ============================================
-- Migration 13: Create Stale Device Checker Function
-- ============================================
-- Purpose: Periodically check for devices that haven't sent data and update their status

CREATE OR REPLACE FUNCTION check_stale_devices()
RETURNS TABLE(device_id TEXT, old_status VARCHAR(20), new_status VARCHAR(20)) AS $$
DECLARE
    v_device RECORD;
    v_seconds_since_last INTEGER;
    v_new_status VARCHAR(20);
    v_quality_score INTEGER;
    v_changed_count INTEGER := 0;
BEGIN
    -- Loop through all active devices
    FOR v_device IN
        SELECT
            m.device_id,
            m.connection_status,
            m.last_data_received_at,
            m.device_status
        FROM moveometers m
        WHERE m.device_status = 'active'
    LOOP
        -- Skip if no data has ever been received
        CONTINUE WHEN v_device.last_data_received_at IS NULL;

        -- Calculate seconds since last data
        v_seconds_since_last := EXTRACT(EPOCH FROM (NOW() - v_device.last_data_received_at))::INTEGER;

        -- Determine new status
        IF v_seconds_since_last <= 20 THEN
            v_new_status := 'online';
            v_quality_score := 100;
        ELSIF v_seconds_since_last <= 60 THEN
            v_new_status := 'stale';
            v_quality_score := 70;
        ELSE
            v_new_status := 'offline';
            v_quality_score := 0;
        END IF;

        -- Only update if status changed
        IF v_device.connection_status IS DISTINCT FROM v_new_status THEN
            -- Update moveometers table
            UPDATE moveometers
            SET
                connection_status = v_new_status,
                connection_status_updated_at = NOW(),
                seconds_since_last_data = v_seconds_since_last,
                connection_quality_score = v_quality_score
            WHERE moveometers.device_id = v_device.device_id;

            -- End previous status period in history
            UPDATE device_status_history
            SET
                ended_at = NOW(),
                duration_seconds = EXTRACT(EPOCH FROM (NOW() - started_at))::INTEGER
            WHERE device_status_history.device_id = v_device.device_id
                AND ended_at IS NULL;

            -- Start new status period
            INSERT INTO device_status_history (device_id, status, started_at)
            VALUES (v_device.device_id, v_new_status, NOW());

            -- Return changed device info
            device_id := v_device.device_id;
            old_status := v_device.connection_status;
            new_status := v_new_status;
            v_changed_count := v_changed_count + 1;
            RETURN NEXT;
        END IF;
    END LOOP;

    RAISE NOTICE 'Checked stale devices: % status changes', v_changed_count;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION check_stale_devices() TO postgres, service_role;

RAISE NOTICE 'Stale device checker function created successfully!';
RAISE NOTICE 'Call this function periodically (every 30s) via pg_cron or Supabase Edge Function';

-- Example usage:
-- SELECT * FROM check_stale_devices();

-- Rollback instructions:
-- DROP FUNCTION IF EXISTS check_stale_devices();
