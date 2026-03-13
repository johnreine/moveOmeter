-- ============================================
-- Migration 12: Create Device Status Update Trigger
-- ============================================
-- Purpose: Automatically update device status on every data insert

CREATE OR REPLACE FUNCTION update_device_status()
RETURNS TRIGGER AS $$
DECLARE
    v_timestamp TIMESTAMPTZ;
    v_seconds_since_last INTEGER;
    v_new_status VARCHAR(20);
    v_old_status VARCHAR(20);
    v_quality_score INTEGER;
BEGIN
    -- Use device_timestamp if available, otherwise use created_at
    v_timestamp := COALESCE(NEW.device_timestamp, NEW.created_at);

    -- Calculate seconds since this data point (should be ~0 for new data)
    v_seconds_since_last := EXTRACT(EPOCH FROM (NOW() - v_timestamp))::INTEGER;

    -- Determine new status based on thresholds
    -- Online: data within last 20 seconds
    -- Stale: data between 20-60 seconds ago
    -- Offline: data older than 60 seconds
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

    -- Get current status from moveometers table
    SELECT connection_status INTO v_old_status
    FROM moveometers
    WHERE device_id = NEW.device_id;

    -- Update device status in moveometers table
    UPDATE moveometers SET
        connection_status = v_new_status,
        connection_status_updated_at = NOW(),
        seconds_since_last_data = v_seconds_since_last,
        last_data_received_at = v_timestamp,
        connection_quality_score = v_quality_score
    WHERE device_id = NEW.device_id;

    -- Record status change in history if status changed
    IF v_old_status IS DISTINCT FROM v_new_status THEN
        -- End the previous status period (if any)
        UPDATE device_status_history
        SET
            ended_at = NOW(),
            duration_seconds = EXTRACT(EPOCH FROM (NOW() - started_at))::INTEGER
        WHERE device_id = NEW.device_id
            AND ended_at IS NULL;

        -- Start a new status period
        INSERT INTO device_status_history (device_id, status, started_at)
        VALUES (NEW.device_id, v_new_status, NOW());

        RAISE NOTICE 'Device % status changed: % → %', NEW.device_id, v_old_status, v_new_status;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_update_device_status ON mmwave_sensor_data;

-- Create trigger on mmwave_sensor_data inserts
CREATE TRIGGER trigger_update_device_status
    AFTER INSERT ON mmwave_sensor_data
    FOR EACH ROW
    EXECUTE FUNCTION update_device_status();

RAISE NOTICE 'Device status trigger created successfully!';
RAISE NOTICE 'Status will now update automatically on each data insert';

-- Rollback instructions:
-- DROP TRIGGER IF EXISTS trigger_update_device_status ON mmwave_sensor_data;
-- DROP FUNCTION IF EXISTS update_device_status();
