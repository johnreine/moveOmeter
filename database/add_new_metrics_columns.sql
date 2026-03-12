-- Add new metric columns to daily_aggregates table
ALTER TABLE daily_aggregates
  ADD COLUMN IF NOT EXISTS offline_minutes INTEGER,
  ADD COLUMN IF NOT EXISTS peak_activity_hour INTEGER CHECK (peak_activity_hour >= 0 AND peak_activity_hour <= 23);

SELECT 'New metric columns added successfully!' as status;
