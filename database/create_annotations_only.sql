-- Simple version - just create the annotations table
DROP TABLE IF EXISTS timeline_annotations CASCADE;

CREATE TABLE timeline_annotations (
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

-- Add indexes
CREATE INDEX idx_timeline_annotations_device
    ON timeline_annotations(device_id, annotation_timestamp DESC);

CREATE INDEX idx_timeline_annotations_timestamp
    ON timeline_annotations(annotation_timestamp DESC);

-- Enable RLS but allow all operations
ALTER TABLE timeline_annotations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable all operations for timeline_annotations" ON timeline_annotations;
CREATE POLICY "Enable all operations for timeline_annotations"
    ON timeline_annotations
    FOR ALL
    USING (true)
    WITH CHECK (true);

SELECT 'Timeline annotations table created!' AS status;
