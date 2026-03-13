-- ============================================
-- Migration 11: Create Device Status History Table
-- ============================================
-- Purpose: Track all device status changes over time for analytics and debugging

CREATE TABLE IF NOT EXISTS device_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL REFERENCES moveometers(device_id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL, -- 'online', 'stale', 'offline'
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure we don't have overlapping periods for same device
    CONSTRAINT check_ended_after_started CHECK (ended_at IS NULL OR ended_at >= started_at)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_device_status_history_device
    ON device_status_history(device_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_device_status_history_ongoing
    ON device_status_history(device_id)
    WHERE ended_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_device_status_history_status
    ON device_status_history(status, started_at DESC);

-- Add comments
COMMENT ON TABLE device_status_history IS 'Historical record of all device status changes';
COMMENT ON COLUMN device_status_history.status IS 'Status during this period: online, stale, offline';
COMMENT ON COLUMN device_status_history.started_at IS 'When this status period began';
COMMENT ON COLUMN device_status_history.ended_at IS 'When this status period ended (NULL if ongoing)';
COMMENT ON COLUMN device_status_history.duration_seconds IS 'Duration of this status period in seconds';

-- Enable RLS
ALTER TABLE device_status_history ENABLE ROW LEVEL SECURITY;

-- Users can view status history for devices they can access
DROP POLICY IF EXISTS "Users can view status history for authorized devices" ON device_status_history;
CREATE POLICY "Users can view status history for authorized devices"
    ON device_status_history FOR SELECT
    USING (
        user_can_access_device(auth.uid(), device_id)
    );

-- System can insert/update status history
DROP POLICY IF EXISTS "System can manage status history" ON device_status_history;
CREATE POLICY "System can manage status history"
    ON device_status_history FOR ALL
    USING (true)
    WITH CHECK (true);

RAISE NOTICE 'Device status history table created successfully!';

-- Rollback instructions:
-- DROP TABLE IF EXISTS device_status_history CASCADE;
