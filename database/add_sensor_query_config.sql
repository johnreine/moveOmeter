-- Add sensor query configuration fields to moveometers table
-- These control how the device queries the mmWave sensor chip

ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS sensor_query_delay_ms INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS enable_supplemental_queries BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS supplemental_cycle_mode TEXT DEFAULT 'rotating',
ADD COLUMN IF NOT EXISTS query_retry_attempts INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS query_retry_delay_ms INTEGER DEFAULT 100;

-- Add comments to describe the fields
COMMENT ON COLUMN moveometers.sensor_query_delay_ms IS 'Delay between individual sensor queries within a collection cycle (milliseconds). Use if sensor needs time between reads.';
COMMENT ON COLUMN moveometers.enable_supplemental_queries IS 'Enable/disable supplemental data queries. If false, only critical data is collected.';
COMMENT ON COLUMN moveometers.supplemental_cycle_mode IS 'How to query supplemental data: "rotating" (cycle through), "all" (query all each time), "none" (disable)';
COMMENT ON COLUMN moveometers.query_retry_attempts IS 'Number of times to retry failed sensor queries (1 = no retry, 2 = retry once, etc.)';
COMMENT ON COLUMN moveometers.query_retry_delay_ms IS 'Delay between sensor query retry attempts (milliseconds)';

-- Add index for faster config lookups
CREATE INDEX IF NOT EXISTS idx_moveometers_sensor_config ON moveometers(device_id, enable_supplemental_queries);
