-- ============================================
-- OTA Firmware Update System
-- ============================================
-- Enables remote firmware updates for moveOmeter devices

-- Firmware versions table
CREATE TABLE IF NOT EXISTS firmware_updates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  version TEXT NOT NULL UNIQUE,
  device_model TEXT NOT NULL DEFAULT 'ESP32C6_MOVEOMETER',
  download_url TEXT NOT NULL,
  file_size_bytes INTEGER,
  md5_checksum TEXT,
  release_notes TEXT,
  mandatory BOOLEAN DEFAULT false,
  min_battery_percent INTEGER DEFAULT 30,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by TEXT
);

-- Add indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_firmware_device_model ON firmware_updates(device_model);
CREATE INDEX IF NOT EXISTS idx_firmware_created_at ON firmware_updates(created_at DESC);

-- Add OTA tracking fields to moveometers table
ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS firmware_version TEXT DEFAULT '1.0.0';

ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS last_ota_check TIMESTAMP WITH TIME ZONE;

ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS last_ota_update TIMESTAMP WITH TIME ZONE;

ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS ota_status TEXT DEFAULT 'idle';

ALTER TABLE moveometers
ADD COLUMN IF NOT EXISTS ota_error TEXT;

-- Comments for clarity
COMMENT ON TABLE firmware_updates IS 'Stores firmware versions available for OTA updates';
COMMENT ON COLUMN firmware_updates.mandatory IS 'If true, device must update to this version';
COMMENT ON COLUMN firmware_updates.min_battery_percent IS 'Minimum battery level required for update';

COMMENT ON COLUMN moveometers.firmware_version IS 'Current firmware version running on device';
COMMENT ON COLUMN moveometers.last_ota_check IS 'Last time device checked for updates';
COMMENT ON COLUMN moveometers.last_ota_update IS 'Last successful firmware update timestamp';
COMMENT ON COLUMN moveometers.ota_status IS 'Current OTA status: idle, checking, downloading, updating, failed, success';
COMMENT ON COLUMN moveometers.ota_error IS 'Last OTA error message if failed';

-- Insert initial firmware version
INSERT INTO firmware_updates (version, device_model, download_url, release_notes)
VALUES ('1.0.0', 'ESP32C6_MOVEOMETER', 'placeholder', 'Initial release')
ON CONFLICT (version) DO NOTHING;

-- Enable RLS (Row Level Security) if needed
ALTER TABLE firmware_updates ENABLE ROW LEVEL SECURITY;

-- Policy to allow read access to firmware updates
CREATE POLICY "Allow public read access to firmware updates"
ON firmware_updates FOR SELECT
USING (true);

-- Policy to allow authenticated users to insert/update firmware
CREATE POLICY "Allow authenticated users to manage firmware"
ON firmware_updates FOR ALL
USING (auth.role() = 'authenticated');

SELECT 'OTA firmware update system created successfully!' AS status;
