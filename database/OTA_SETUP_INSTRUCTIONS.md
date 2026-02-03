# OTA Firmware Update System Setup Guide

This guide will help you set up Over-The-Air (OTA) firmware updates for your moveOmeter devices.

## Prerequisites

1. **ESP32 Board**: Adafruit ESP32-C6 Feather
2. **Arduino IDE** with ESP32 board support installed
3. **Supabase Project** with Storage enabled
4. **Libraries Installed**:
   - DFRobot_HumanDetection
   - ESPSupabase
   - HTTPUpdate (built-in with ESP32)
   - WiFiClientSecure (built-in with ESP32)

## Step 1: Database Setup

Run the SQL script to create the necessary tables and columns:

```bash
# Connect to your Supabase database and run:
psql -h <your-supabase-host> -U postgres -d postgres -f add_ota_system.sql
```

Or use the Supabase SQL Editor to paste and run `add_ota_system.sql`.

## Step 2: Supabase Storage Setup

1. Go to your Supabase Dashboard
2. Navigate to **Storage** → **Create a new bucket**
3. Create a bucket named: `firmware`
4. Set the bucket to **Public** (for device downloads)
5. Add a policy to allow public reads:

```sql
-- Allow public download of firmware files
CREATE POLICY "Public firmware downloads"
ON storage.objects FOR SELECT
USING (bucket_id = 'firmware');
```

## Step 3: Arduino IDE Partition Scheme

The ESP32 needs an OTA-compatible partition scheme:

1. Open Arduino IDE
2. Go to **Tools** → **Board** → Select "Adafruit Feather ESP32-C6"
3. Go to **Tools** → **Partition Scheme**
4. Select: **"Minimal SPIFFS (1.9MB APP with OTA/190KB SPIFFS)"**

This reserves space for both the current firmware and the new firmware during OTA updates.

## Step 4: Firmware Configuration

The current firmware is already configured for OTA. Key settings:

```cpp
#define FIRMWARE_VERSION "1.0.0"  // Update this with each release
#define DEVICE_MODEL "ESP32C6_MOVEOMETER"
#define OTA_CHECK_INTERVAL 3600000  // Check every 1 hour
```

## Step 5: Compile and Upload Initial Firmware

1. Open `mmWave_Supabase_collector.ino` in Arduino IDE
2. Update `config.h` with your WiFi and Supabase credentials
3. Verify FIRMWARE_VERSION is set to "1.0.0"
4. Upload to the ESP32 via USB

The device will:
- Connect to WiFi
- Report its firmware version to Supabase
- Check for updates every hour
- Automatically download and install new firmware when available

## Step 6: Using the Web Interface

### Access Firmware Management

1. Open `http://localhost/firmware.html` (or wherever you're hosting the dashboard)
2. You'll see:
   - **Device Status**: Current firmware version and OTA status
   - **Upload New Firmware**: Interface to publish new versions
   - **Firmware History**: List of all published versions

### Publishing a New Firmware Version

1. **Compile the new firmware**:
   - Update `FIRMWARE_VERSION` in the .ino file (e.g., "1.0.1")
   - Make your code changes
   - Go to **Sketch** → **Export Compiled Binary**
   - Find the .bin file in your sketch folder

2. **Upload via Web Interface**:
   - Click "Choose Firmware File"
   - Select the .bin file
   - Enter version number (e.g., "1.0.1")
   - Add release notes (what changed?)
   - Check "Mandatory Update" if devices must install it
   - Click "Publish Firmware"

3. **Device Updates Automatically**:
   - Within 1 hour, the device will check for updates
   - It will download and install the new firmware
   - The device will reboot automatically
   - Status will update in the dashboard

## Step 7: Monitoring OTA Updates

Watch the Serial Monitor to see OTA progress:

```
[OTA] Checking for firmware updates...
Current version: 1.0.0
[OTA] Latest version: 1.0.1
[OTA] New version available: 1.0.1
[OTA] Starting firmware update...
[OTA] Downloading and flashing firmware...
[OTA] Update successful!
[OTA] Rebooting...
```

You can also monitor in the web dashboard:
- **OTA Status**: Shows current state (idle, checking, downloading, updating, success, failed)
- **Last Check**: When the device last checked for updates
- **Last Update**: When the last successful update was installed

## Triggering Manual OTA Check

To make the device check immediately instead of waiting 1 hour:

1. Add a command to the device_commands system:
```sql
UPDATE moveometers
SET pending_command = 'check_ota'
WHERE device_id = 'ESP32C6_001';
```

2. Or reboot the device (it checks 1 minute after boot)

## Safety Features

The OTA system includes several safety measures:

1. **Version Comparison**: Only updates if new version is higher
2. **MD5 Checksum**: Verifies file integrity before flashing
3. **Rollback**: ESP32 automatically rolls back if new firmware crashes
4. **Status Tracking**: All OTA attempts are logged in the database
5. **Update Windows**: Only checks every 1 hour to avoid excessive checking

## Troubleshooting

### Device Won't Update

1. Check Serial Monitor for error messages
2. Verify `ota_status` in database:
   ```sql
   SELECT device_id, firmware_version, ota_status, ota_error
   FROM moveometers
   WHERE device_id = 'ESP32C6_001';
   ```
3. Ensure firmware file is accessible:
   - Try downloading the URL manually
   - Check Supabase Storage bucket permissions

### Update Failed

Common errors:

- **"HTTP 404"**: Firmware file not found, check URL
- **"MD5 mismatch"**: File corrupted, re-upload
- **"Not enough space"**: Partition scheme too small, change in Arduino IDE
- **"Download timeout"**: Network issue, device will retry on next check

### Force Fresh Update

If a device is stuck:

```sql
-- Reset OTA status
UPDATE moveometers
SET ota_status = 'idle',
    ota_error = NULL
WHERE device_id = 'ESP32C6_001';
```

Then reboot the device or wait for next check interval.

## Best Practices

1. **Always test firmware locally** before publishing via OTA
2. **Increment version numbers** properly (major.minor.patch)
3. **Write clear release notes** for each version
4. **Use mandatory updates sparingly** - only for critical fixes
5. **Monitor the first few devices** before rolling out to all
6. **Keep old versions** in case you need to roll back
7. **Test OTA with one device first** before mass deployment

## Security Considerations

- Use HTTPS for firmware downloads (Supabase provides this)
- Consider adding firmware signing for production
- Implement device authentication for firmware access
- Monitor failed OTA attempts for suspicious activity
- Regularly audit firmware update logs

## Production Deployment

For deploying to multiple devices:

1. **Staged Rollout**:
   - Update 1-2 test devices first
   - Monitor for 24 hours
   - If stable, push to 10% of fleet
   - Gradually increase to 100%

2. **Targeting Specific Devices**:
   ```sql
   -- Add targeting logic in firmware query
   WHERE device_id IN ('ESP32C6_001', 'ESP32C6_002')
   OR location = 'Building_A'
   ```

3. **Emergency Rollback**:
   - Keep previous firmware version available
   - Publish old version with higher version number
   - Mark as mandatory to force rollback

## Support

For issues or questions:
- Check Serial Monitor output
- Review database logs
- Check Supabase Storage logs
- Test firmware locally first

---

**Version**: 1.0.0
**Last Updated**: 2025
**Author**: moveOmeter Development Team
