-- Add data collection mode setting to moveometers table
-- This allows choosing between "quick" and "medium" data collection modes

-- Add the column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'moveometers' AND column_name = 'data_collection_mode'
    ) THEN
        ALTER TABLE moveometers
        ADD COLUMN data_collection_mode TEXT DEFAULT 'quick' CHECK (data_collection_mode IN ('quick', 'medium'));

        RAISE NOTICE 'Added data_collection_mode column to moveometers table';
    ELSE
        RAISE NOTICE 'data_collection_mode column already exists';
    END IF;
END $$;

-- Update any existing devices to have the default value
UPDATE moveometers
SET data_collection_mode = 'quick'
WHERE data_collection_mode IS NULL;

SELECT 'Data collection mode setting added!' AS status;
