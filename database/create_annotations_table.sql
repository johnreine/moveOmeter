-- Create table for user-created timeline annotations
CREATE TABLE IF NOT EXISTS timeline_annotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    annotation_timestamp TIMESTAMPTZ NOT NULL,
    annotation_type TEXT NOT NULL DEFAULT 'custom',
    title TEXT NOT NULL,
    description TEXT,
    color TEXT DEFAULT '#667eea',
    icon TEXT DEFAULT '📝',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by TEXT
);

-- Add indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_timeline_annotations_device
    ON timeline_annotations(device_id, annotation_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_timeline_annotations_timestamp
    ON timeline_annotations(annotation_timestamp DESC);

-- Add RLS policies (adjust based on your auth setup)
ALTER TABLE timeline_annotations ENABLE ROW LEVEL SECURITY;

-- Allow all operations for now (update based on your auth requirements)
CREATE POLICY "Enable all operations for timeline_annotations"
    ON timeline_annotations
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_timeline_annotations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_timeline_annotations_updated_at
    BEFORE UPDATE ON timeline_annotations
    FOR EACH ROW
    EXECUTE FUNCTION update_timeline_annotations_updated_at();

-- Add comments
COMMENT ON TABLE timeline_annotations IS 'User-created annotations for timeline visualization';
COMMENT ON COLUMN timeline_annotations.annotation_type IS 'Type of annotation: custom, medication, appointment, note, fall, etc.';
COMMENT ON COLUMN timeline_annotations.color IS 'Hex color code for annotation display';
COMMENT ON COLUMN timeline_annotations.icon IS 'Emoji or icon for annotation marker';
