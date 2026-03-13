-- ============================================
-- Migration 10: Add Device Status Columns
-- ============================================
-- Purpose: Add server-side device status tracking to moveometers table
-- This removes the need for clients to calculate online/offline status

-- Add status tracking columns to moveometers table
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS connection_status VARCHAR(20) DEFAULT 'unknown',
ADD COLUMN IF NOT EXISTS connection_status_updated_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS seconds_since_last_data INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS connection_quality_score INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_data_received_at TIMESTAMPTZ;

-- Add comments for documentation
COMMENT ON COLUMN moveometers.connection_status IS 'Current connection status: online, stale, offline, unknown';
COMMENT ON COLUMN moveometers.connection_status_updated_at IS 'Timestamp when connection_status was last updated';
COMMENT ON COLUMN moveometers.seconds_since_last_data IS 'Seconds since last data was received';
COMMENT ON COLUMN moveometers.connection_quality_score IS 'Connection quality score 0-100 (100=excellent, 0=offline)';
COMMENT ON COLUMN moveometers.last_data_received_at IS 'Timestamp of most recent data received (device_timestamp or created_at)';

-- Create index for efficient status queries
CREATE INDEX IF NOT EXISTS idx_moveometers_connection_status ON moveometers(connection_status, device_status);

-- Success message
DO $$ BEGIN
    RAISE NOTICE 'Device status columns added successfully!';
END $$;

-- Rollback instructions:
-- ALTER TABLE moveometers DROP COLUMN connection_status;
-- ALTER TABLE moveometers DROP COLUMN connection_status_updated_at;
-- ALTER TABLE moveometers DROP COLUMN seconds_since_last_data;
-- ALTER TABLE moveometers DROP COLUMN connection_quality_score;
-- ALTER TABLE moveometers DROP COLUMN last_data_received_at;
-- DROP INDEX IF EXISTS idx_moveometers_connection_status;
