-- Daily Aggregates Table
-- Stores calculated daily metrics for each moveOmeter device
-- This table is populated by aggregating raw sensor data once per day

CREATE TABLE IF NOT EXISTS daily_aggregates (
  -- Primary identification
  id BIGSERIAL PRIMARY KEY,
  device_id TEXT NOT NULL,
  date DATE NOT NULL,

  -- Activity Metrics
  motion_score INTEGER CHECK (motion_score >= 0 AND motion_score <= 100), -- Overall daily activity score (0-100)
  first_motion_time TIMESTAMPTZ, -- First movement detected (wake-up indicator)
  last_motion_time TIMESTAMPTZ, -- Last movement detected (bedtime indicator)
  total_active_minutes INTEGER, -- Total minutes with movement detected
  total_stationary_minutes INTEGER, -- Total minutes with no movement
  longest_stationary_minutes INTEGER, -- Longest continuous period without movement
  movement_sessions INTEGER, -- Number of distinct movement sessions (got up/moved)
  average_movement_intensity DECIMAL(5,2), -- Mean movement value when active (0-100)
  peak_movement_time TIMESTAMPTZ, -- Time of highest activity

  -- Safety Metrics
  fall_count INTEGER DEFAULT 0, -- Number of falls detected
  total_time_on_floor_minutes INTEGER, -- Total time in fallen position
  fall_timestamps JSONB, -- Array of fall event timestamps for detailed review

  -- Pattern Metrics (estimated from movement patterns)
  estimated_bathroom_trips INTEGER, -- Estimated trips based on movement patterns
  estimated_sleep_start TIMESTAMPTZ, -- Estimated bedtime
  estimated_sleep_end TIMESTAMPTZ, -- Estimated wake time
  estimated_sleep_hours DECIMAL(4,2), -- Estimated hours of sleep

  -- Sleep Mode Specific Metrics (populated if device in sleep mode)
  sleep_quality_score INTEGER CHECK (sleep_quality_score >= 0 AND sleep_quality_score <= 100),
  deep_sleep_percentage DECIMAL(5,2),
  light_sleep_percentage DECIMAL(5,2),
  wake_events INTEGER, -- Number of times woke during sleep
  apnea_events INTEGER, -- Sleep apnea events detected
  average_heart_rate DECIMAL(5,2), -- Average heart rate during sleep
  average_respiration_rate DECIMAL(5,2), -- Average breathing rate

  -- Trend Analysis (compared to baseline)
  variance_from_baseline_pct DECIMAL(5,2), -- % difference from personal average
  trend_direction TEXT CHECK (trend_direction IN ('improving', 'stable', 'declining', 'insufficient_data')),

  -- Data Quality
  data_points_count INTEGER, -- Number of raw data points used for calculation
  data_coverage_pct DECIMAL(5,2), -- % of day with data (should be ~100%)
  calculation_method TEXT DEFAULT 'automated', -- 'automated' or 'manual_override'

  -- Metadata
  calculated_at TIMESTAMPTZ DEFAULT NOW(), -- When metrics were calculated
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure one record per device per day
  UNIQUE(device_id, date)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_daily_aggregates_device_date ON daily_aggregates(device_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_aggregates_date ON daily_aggregates(date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_aggregates_motion_score ON daily_aggregates(motion_score);
CREATE INDEX IF NOT EXISTS idx_daily_aggregates_fall_count ON daily_aggregates(fall_count) WHERE fall_count > 0;

-- Comments for documentation
COMMENT ON TABLE daily_aggregates IS 'Daily aggregated metrics calculated from raw sensor data for trend analysis and reporting';
COMMENT ON COLUMN daily_aggregates.motion_score IS 'Overall daily activity score (0=no movement, 100=very active)';
COMMENT ON COLUMN daily_aggregates.variance_from_baseline_pct IS 'Percentage difference from individuals 30-day moving average';
COMMENT ON COLUMN daily_aggregates.data_coverage_pct IS 'Percentage of 24-hour period with valid data points';

-- Enable Row Level Security (RLS)
ALTER TABLE daily_aggregates ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow all authenticated users to read (adjust as needed)
CREATE POLICY daily_aggregates_select_policy ON daily_aggregates
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Grant permissions
GRANT SELECT ON daily_aggregates TO authenticated;
GRANT ALL ON daily_aggregates TO service_role;
