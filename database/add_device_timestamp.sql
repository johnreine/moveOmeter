-- Add device timestamp field for accurate time tracking
-- This is the exact time the sensor reading was taken (from device's NTP-synced clock)
-- vs created_at which is when Supabase received the data

ALTER TABLE mmwave_sensor_data
ADD COLUMN IF NOT EXISTS device_timestamp TIMESTAMPTZ;

-- Add index for time-based queries
CREATE INDEX IF NOT EXISTS idx_device_timestamp ON mmwave_sensor_data(device_timestamp DESC);

-- Add index for device + time queries
CREATE INDEX IF NOT EXISTS idx_device_time ON mmwave_sensor_data(device_id, device_timestamp DESC);

-- Add comment
COMMENT ON COLUMN mmwave_sensor_data.device_timestamp IS 'Exact time sensor reading was taken (device NTP-synced clock). More accurate than created_at for analysis.';

-- View to compare timestamps (for debugging)
CREATE OR REPLACE VIEW timestamp_comparison AS
SELECT
    device_id,
    device_timestamp,
    created_at,
    EXTRACT(EPOCH FROM (created_at - device_timestamp)) as delay_seconds
FROM mmwave_sensor_data
WHERE device_timestamp IS NOT NULL
ORDER BY created_at DESC
LIMIT 100;

COMMENT ON VIEW timestamp_comparison IS 'Compare device timestamp vs server timestamp to see upload delays';
