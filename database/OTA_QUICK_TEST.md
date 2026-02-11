# OTA Update Quick Test Guide

## Current Status

The Arduino firmware now has OTA update checking enabled:
- ✅ Periodic config checks every 60 seconds
- ✅ Periodic OTA checks (default: 1 hour, configurable in database)

## Quick Testing Steps

### 1. Setup Database for Testing (2-minute interval)

Run this SQL in Supabase:
```bash
# From your terminal:
cd /Users/johnreine/Dropbox/john/2025_work/moveOmeter/database
# Copy and paste setup_ota_testing.sql into Supabase SQL Editor
```

This sets the OTA check interval to 2 minutes instead of 1 hour.

### 2. Upload Current Firmware to Your Device

1. Open Arduino IDE
2. Go to **Tools** → **Partition Scheme** → Select **"Minimal SPIFFS (1.9MB APP with OTA/190KB SPIFFS)"**
3. Open `mmWave_Supabase_collector.ino`
4. Verify `FIRMWARE_VERSION` is "1.0.0" (line 28)
5. Upload to ESP32-C6 via USB
6. Open Serial Monitor - you should see:
   ```
   [Periodic Config Check]
   [OTA] Checking for firmware updates...
   Current version: 1.0.0
   [OTA] Already on latest version
   ```

### 3. Create a Test Firmware Update

1. In Arduino IDE, change `FIRMWARE_VERSION`:
   ```cpp
   #define FIRMWARE_VERSION "1.0.1"  // Changed from 1.0.0
   ```

2. Add a visible change (optional, for verification):
   ```cpp
   // In setup(), after "Starting data collection..." line, add:
   USB_SERIAL.println("*** RUNNING VERSION 1.0.1 - TEST UPDATE ***");
   ```

3. Export the firmware binary:
   - Go to **Sketch** → **Export Compiled Binary**
   - Wait for compilation to finish
   - Find the .bin file in your sketch folder:
     `pictureFrame/software/mmWave_Supabase_collector/build/.../*.bin`
   - Look for the file WITHOUT "bootloader" in the name

### 4. Upload Firmware to Supabase Storage

1. Go to Supabase Dashboard → **Storage**
2. Create bucket named `firmware` (if it doesn't exist)
   - Set to **Public**
3. Upload your .bin file
4. Get the public URL (click the file → Copy URL)
   - Should look like: `https://YOUR-PROJECT.supabase.co/storage/v1/object/public/firmware/v1.0.1.bin`

### 5. Create Firmware Update Record

Run this SQL in Supabase (replace the URL with yours):
```sql
INSERT INTO firmware_updates (
    version,
    device_model,
    download_url,
    release_notes,
    mandatory
) VALUES (
    '1.0.1',
    'ESP32C6_MOVEOMETER',
    'https://YOUR-PROJECT.supabase.co/storage/v1/object/public/firmware/v1.0.1.bin',
    'Test OTA update - added version message',
    false
);
```

### 6. Watch the Magic Happen

Within 2 minutes, your Serial Monitor should show:
```
[OTA] Checking for firmware updates...
Current version: 1.0.0
[OTA] Latest version: 1.0.1
[OTA] New version available: 1.0.1
[OTA] Starting firmware update...
[OTA] Downloading and flashing firmware...
[OTA] Progress: 0%
[OTA] Progress: 25%
[OTA] Progress: 50%
[OTA] Progress: 75%
[OTA] Progress: 100%
[OTA] Update successful!
[OTA] Rebooting...

*** RUNNING VERSION 1.0.1 - TEST UPDATE ***
```

The device will reboot automatically and start running the new firmware!

## Verify Update Success

Check in Supabase:
```sql
SELECT device_id,
       firmware_version,
       last_ota_check,
       last_ota_update,
       ota_status
FROM moveometers
WHERE device_id = 'ESP32C6_001';
```

You should see:
- `firmware_version`: "1.0.1"
- `ota_status`: "success"
- `last_ota_update`: recent timestamp

## Troubleshooting

### Device shows "No firmware updates available"
- Verify the firmware_updates record exists: `SELECT * FROM firmware_updates;`
- Check that version is higher than current: "1.0.1" > "1.0.0"

### Download fails (HTTP 404)
- Verify the download URL is correct and public
- Try accessing the URL in your browser
- Check Supabase Storage bucket permissions (must be public)

### MD5 checksum error
- The binary file got corrupted during upload
- Re-upload to Supabase Storage

### Device won't reboot after update
- The ESP32 has automatic rollback - it will revert to 1.0.0
- Check Serial Monitor for error messages
- Verify you selected the correct partition scheme

## After Testing: Reset to Normal Interval

When done testing, set OTA check back to 1 hour:
```sql
UPDATE moveometers
SET ota_check_interval_ms = 3600000  -- 1 hour
WHERE device_id = 'ESP32C6_001';
```

## Next Steps

Once OTA is working:
1. Create a web interface for uploading firmware (like firmware.html)
2. Add MD5 checksum calculation during upload
3. Set up staging/production firmware channels
4. Implement gradual rollout to multiple devices

---
**Ready to test?** Start with Step 1 above!
