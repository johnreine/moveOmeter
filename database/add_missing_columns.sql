-- Add missing columns to daily_aggregates table
ALTER TABLE daily_aggregates 
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

SELECT 'Columns added successfully!' as status;
