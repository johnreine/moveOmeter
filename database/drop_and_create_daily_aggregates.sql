-- Drop existing table and recreate from scratch
DROP TABLE IF EXISTS daily_aggregates CASCADE;

-- Create daily_aggregates table
CREATE TABLE daily_aggregates (
  id BIGSERIAL PRIMARY KEY,
  device_id TEXT NOT NULL,
  date DATE NOT NULL,

  -- Core metrics
  motion_score INTEGER CHECK (motion_score >= 0 AND motion_score <= 100),
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

-- Create index
CREATE INDEX idx_daily_aggregates_device_date ON daily_aggregates(device_id, date DESC);

-- Success message
SELECT 'daily_aggregates table created successfully!' as status;
