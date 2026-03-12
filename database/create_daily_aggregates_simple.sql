-- Simple version for testing
CREATE TABLE IF NOT EXISTS daily_aggregates (
  id BIGSERIAL PRIMARY KEY,
  device_id TEXT NOT NULL,
  date DATE NOT NULL,

  -- Core metrics
  motion_score INTEGER,
  first_motion_time TIMESTAMPTZ,
  last_motion_time TIMESTAMPTZ,
  total_active_minutes INTEGER,
  longest_stationary_minutes INTEGER,
  movement_sessions INTEGER,
  average_movement_intensity DECIMAL(5,2),
  fall_count INTEGER DEFAULT 0,

  -- Metadata
  data_points_count INTEGER,
  data_coverage_pct DECIMAL(5,2),
  calculated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(device_id, date)
);

-- Create index (if not exists)
CREATE INDEX IF NOT EXISTS idx_daily_aggregates_device_date ON daily_aggregates(device_id, date DESC);
