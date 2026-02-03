# Configurable Sampling Rates

The moveOmeter system now supports fully configurable sampling rates through the web UI, stored in Supabase and applied to devices in real-time.

## Overview

All data collection intervals are now configurable through sliders in the web dashboard's Settings panel. Changes are synced to the device within seconds.

## Database Setup

1. Run the SQL migration to add the new columns:

```bash
psql -h <your-supabase-host> -U postgres -d postgres -f database/add_sampling_rate_config.sql
```

Or execute directly in the Supabase SQL Editor:
- Go to Supabase Dashboard → SQL Editor
- Copy contents of `database/add_sampling_rate_config.sql`
- Execute

## Configurable Parameters

### 1. Fall Detection Sampling Rate
- **Field**: `fall_detection_interval_ms`
- **Default**: 20000ms (20 seconds)
- **Range**: 5-60 seconds
- **Description**: How often the device collects and uploads data in Fall Detection mode
- **Impact**: Lower = faster fall detection, higher battery/network usage

### 2. Sleep Mode Sampling Rate
- **Field**: `sleep_mode_interval_ms`
- **Default**: 20000ms (20 seconds)
- **Range**: 10-120 seconds
- **Description**: How often the device collects and uploads data in Sleep mode
- **Impact**: Lower = more detailed sleep tracking, higher battery/network usage

### 3. Config Check Interval
- **Field**: `config_check_interval_ms`
- **Default**: 20000ms (20 seconds)
- **Range**: 5-60 seconds
- **Description**: How often the device checks for configuration updates from the server
- **Impact**: Lower = faster response to setting changes, slightly higher network usage

### 4. Firmware Check Interval
- **Field**: `ota_check_interval_ms`
- **Default**: 3600000ms (60 minutes)
- **Range**: 30 minutes - 24 hours
- **Description**: How often the device checks for firmware updates
- **Impact**: Checking too frequently wastes bandwidth; once per hour is recommended

## Web UI Configuration

1. Open the moveOmeter dashboard
2. Click on **⚙️ Device Configuration** to expand the settings panel
3. Adjust the sampling rate sliders under **📊 General Settings**
4. Click **💾 Save Settings to Device**
5. The device will sync within the configured Config Check Interval

## How It Works

### Device Sync Process

1. User changes a sampling rate slider in the web UI
2. Web UI saves the new value to Supabase `moveometers` table
3. Web UI sets `config_updated = true` flag
4. Device checks for config updates every `config_check_interval_ms`
5. Device detects the `config_updated` flag
6. Device fetches all configuration values
7. Device applies the new intervals immediately
8. Device clears the `config_updated` flag

### Real-Time Application

The device uses these intervals in its main loop:

```cpp
// Data collection
if (currentTime - lastQuickDataTime >= getDataInterval()) {
  // getDataInterval() returns either fallDetectionIntervalMs or sleepModeIntervalMs
  collectAndUploadQuickData();
}

// Config updates check
if (currentTime - lastConfigCheckTime >= deviceConfig.configCheckIntervalMs) {
  checkForConfigUpdates();
}

// Firmware updates check
if (currentTime - lastOtaCheckTime >= deviceConfig.otaCheckIntervalMs) {
  checkForFirmwareUpdate();
}
```

## Battery Impact

Lower sampling rates mean more frequent data transmission:

| Interval | Battery Impact | Use Case |
|----------|---------------|----------|
| 5 sec | Very High | Critical monitoring, testing |
| 10 sec | High | Active monitoring periods |
| 20 sec | Moderate | Standard monitoring (default) |
| 30 sec | Low | Extended battery life |
| 60+ sec | Very Low | Long-term monitoring |

## Network Usage

Approximate data usage based on sampling rates:

- **20 seconds**: ~180 uploads/hour = ~4,320 uploads/day
- **10 seconds**: ~360 uploads/hour = ~8,640 uploads/day
- **60 seconds**: ~60 uploads/hour = ~1,440 uploads/day

Each upload is approximately 200-500 bytes of JSON data.

## Best Practices

1. **Fall Detection Mode**: Keep at 10-20 seconds for responsive fall alerts
2. **Sleep Mode**: Can use 30-60 seconds for adequate sleep tracking
3. **Config Check**: 20 seconds provides good responsiveness without overhead
4. **OTA Check**: Once per hour is sufficient; daily checks also work well

## Factory Reset

To reset all sampling rates to defaults:
1. Open the web dashboard
2. Go to Device Configuration
3. Click **🔄 Factory Defaults**
4. Click **💾 Save Settings to Device**

Default values:
- Fall Detection: 20 seconds
- Sleep Mode: 20 seconds
- Config Check: 20 seconds
- OTA Check: 60 minutes

## Troubleshooting

### Settings not applying to device
- Check that `config_updated` flag is being set in database
- Verify device is online and connected to WiFi
- Check device serial output for config sync messages
- Reduce Config Check Interval temporarily to speed up sync

### High battery drain
- Increase sampling intervals to 30-60 seconds
- Check that intervals are being applied (view serial output)
- Consider using Sleep mode when possible

### Delayed responses to setting changes
- Decrease Config Check Interval to 5-10 seconds
- Note: Device checks config every N seconds, so worst-case delay is 2x the interval

## Advanced Usage

### Per-Device Configuration

Each device can have different sampling rates:

```sql
-- Set aggressive monitoring for Device 1 (high-risk patient)
UPDATE moveometers
SET fall_detection_interval_ms = 5000,
    sleep_mode_interval_ms = 10000
WHERE device_id = 'ESP32C6_001';

-- Set conservative monitoring for Device 2 (battery conservation)
UPDATE moveometers
SET fall_detection_interval_ms = 60000,
    sleep_mode_interval_ms = 120000
WHERE device_id = 'ESP32C6_002';
```

### Monitoring Sync Status

Check when devices last synced their configuration:

```sql
SELECT device_id,
       config_updated,
       fall_detection_interval_ms,
       sleep_mode_interval_ms,
       updated_at
FROM moveometers;
```

## Future Enhancements

Potential additions:
- Adaptive sampling (increase frequency when activity detected)
- Time-based schedules (faster during day, slower at night)
- Battery-aware sampling (adjust based on battery level)
- Network-aware sampling (adjust based on WiFi signal strength)
