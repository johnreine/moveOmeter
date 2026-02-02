# Online Configuration System Setup

## Overview

The moveOmeter now fetches all configuration settings from Supabase, allowing you to manage devices remotely without re-uploading firmware. Settings are automatically synchronized every 10 minutes.

---

## 🗄️ Database Setup

### Step 1: Create Tables

Run the SQL script in Supabase SQL Editor:

```bash
cat database/create_moveometer_tables.sql
```

This creates:
- **moveometer_models** - Device model definitions
- **moveometers** - Individual device configurations
- **moveometer_config_history** - Configuration change tracking

### Step 2: Verify Sample Data

Your device `ESP32C6_001` should already be in the `moveometers` table with default settings:

```sql
SELECT device_id, operational_mode, data_interval_ms, install_height_cm, device_status
FROM moveometers
WHERE device_id = 'ESP32C6_001';
```

---

## 📋 Configuration Fields

### Device Identification
- `device_id` - Unique identifier (e.g., "ESP32C6_001")
- `serial_number` - Manufacturing serial number
- `mac_address` - Device MAC address
- `location_name` - Physical location (e.g., "bedroom_1")

### Operational Settings
- **`operational_mode`** - `"sleep"` or `"fall_detection"` ⭐
- **`data_interval_ms`** - Milliseconds between readings (default: 1000)
- `device_status` - "active", "inactive", "error", "maintenance"

### Fall Detection Mode Settings
- `fall_sensitivity` - Sensitivity level 1-9 (default: 5)
- `fall_break_height_cm` - Height threshold for falls (default: 100)
- `install_height_cm` - Sensor mounting height (default: 250)
- `install_angle` - Sensor tilt angle in degrees (default: 0)

### Sleep Monitoring Mode Settings
- `sleep_detection_distance_cm` - Max distance for sleep detection (default: 250)
- `breathing_alert_min` - Alert if breathing < this (default: 10)
- `breathing_alert_max` - Alert if breathing > this (default: 25)
- `heart_rate_alert_min` - Min heart rate alert (default: 60)
- `heart_rate_alert_max` - Max heart rate alert (default: 100)
- `apnea_alert_threshold` - Number of apnea events to trigger alert (default: 3)

### Position Tracking
- `position_tracking_enabled` - Enable/disable position tracking (default: true)
- `track_frequency_hz` - Tracking update frequency (default: 1)
- `room_width_ft` - Room width in feet (default: 15.0)
- `room_length_ft` - Room length in feet (default: 20.0)

### Network Settings
- `wifi_ssid` - WiFi network name
- `wifi_password_encrypted` - Encrypted WiFi password
- `mqtt_broker` - MQTT broker address (future use)

---

## 🔧 How It Works

### On Device Boot:
1. ESP32 connects to WiFi
2. Fetches configuration from `moveometers` table by `device_id`
3. Applies settings to mmWave sensor
4. Begins data collection

### During Operation:
- Checks for config updates every **10 minutes**
- Applies any changes automatically
- Logs configuration changes to `moveometer_config_history`

### Configuration Flow:
```
Supabase moveometers table
        ↓
   [Arduino Firmware]
        ↓
   mmWave Sensor
        ↓
   Supabase sensor_data table
```

---

## 🎮 Changing Configuration

### Switch Between Sleep and Fall Detection Modes

**Option 1: Via Supabase Dashboard**
```sql
UPDATE moveometers
SET operational_mode = 'sleep'  -- or 'fall_detection'
WHERE device_id = 'ESP32C6_001';
```

**Option 2: Via Web UI** (future feature)
- Dashboard settings page
- Click "Switch Mode" button
- Changes take effect within 10 minutes

### Change Data Collection Rate

```sql
-- Faster sampling (500ms = 2Hz)
UPDATE moveometers
SET data_interval_ms = 500
WHERE device_id = 'ESP32C6_001';

-- Slower sampling (2 seconds = 0.5Hz)
UPDATE moveometers
SET data_interval_ms = 2000
WHERE device_id = 'ESP32C6_001';
```

### Adjust Installation Height

```sql
UPDATE moveometers
SET install_height_cm = 300  -- 3 meters
WHERE device_id = 'ESP32C6_001';
```

### Change Fall Sensitivity

```sql
-- More sensitive (detects smaller falls)
UPDATE moveometers
SET fall_sensitivity = 8
WHERE device_id = 'ESP32C6_001';

-- Less sensitive (only detects major falls)
UPDATE moveometers
SET fall_sensitivity = 3
WHERE device_id = 'ESP32C6_001';
```

---

## 📊 Monitor Configuration Changes

View configuration history:

```sql
SELECT
    change_timestamp,
    field_changed,
    old_value,
    new_value,
    change_reason
FROM moveometer_config_history
WHERE device_id = (SELECT id FROM moveometers WHERE device_id = 'ESP32C6_001')
ORDER BY change_timestamp DESC
LIMIT 10;
```

---

## 🚀 Firmware Upload

### Step 1: Update Config (if needed)

Edit `config.h` to ensure `DEVICE_ID` matches your database entry:

```cpp
#define DEVICE_ID "ESP32C6_001"
```

### Step 2: Upload Firmware

1. Open Arduino IDE
2. Load `mmWave_Supabase_collector.ino`
3. Upload to ESP32-C6
4. Open Serial Monitor (115200 baud)

### Step 3: Verify Configuration Fetch

You should see:

```
=================================
mmWave Supabase Data Collector
=================================
Connecting to WiFi: Pleasevote... CONNECTED!
Syncing time with NTP servers... SUCCESS!
Initializing Supabase... SUCCESS!
Initializing sensor... SUCCESS!
Sensor initialized! Fetching config...

Fetching device config from database... SUCCESS!
Config received:
{...}
  Mode: fall_detection
  Data Interval: 1000 ms
  Install Height: 250 cm
  Fall Sensitivity: 5
  Position Tracking: Enabled

Applying configuration to sensor...
  Configuring FALL DETECTION MODE... SUCCESS!
  Setting fall sensitivity to 5... DONE!
  Setting installation height to 250 cm... DONE!
Configuration applied successfully!

=================================
Monitoring active!
Calibrating sensor (wait 30-60 seconds)...
```

---

## 🔄 Configuration Sync Behavior

### Automatic Updates
- Device checks for config updates **every 10 minutes**
- No firmware upload needed for config changes
- Changes apply immediately after sync

### Force Immediate Update
Restart the device:
1. Press reset button on ESP32-C6, or
2. Power cycle the device

### What Triggers Config Fetch?
- Device boot/restart
- Every 10 minutes during operation
- After WiFi reconnection (optional future feature)

---

## 🏢 Multi-Device Management

### Add Multiple Devices

```sql
INSERT INTO moveometers (
    device_id,
    serial_number,
    location_name,
    operational_mode,
    data_interval_ms,
    install_height_cm,
    device_status
) VALUES
    ('ESP32C6_002', 'SN-20260202-002', 'bathroom', 'fall_detection', 1000, 250, 'active'),
    ('ESP32C6_003', 'SN-20260202-003', 'living_room', 'sleep', 1000, 250, 'active'),
    ('ESP32C6_004', 'SN-20260202-004', 'bedroom_2', 'fall_detection', 500, 280, 'active');
```

### View All Active Devices

```sql
SELECT * FROM active_moveometers;
```

### Bulk Configuration Changes

```sql
-- Set all devices to 1-second intervals
UPDATE moveometers
SET data_interval_ms = 1000
WHERE device_status = 'active';

-- Set all bedroom devices to sleep mode
UPDATE moveometers
SET operational_mode = 'sleep'
WHERE location_name LIKE 'bedroom%';
```

---

## 🔍 Troubleshooting

### Device Not Fetching Config

**Check Serial Monitor for:**
```
Fetching device config from database... FAILED or device not found in database!
Using default configuration.
```

**Solutions:**
1. Verify `device_id` exists in database:
   ```sql
   SELECT * FROM moveometers WHERE device_id = 'ESP32C6_001';
   ```
2. Check Supabase API key in `config.h`
3. Ensure WiFi is connected
4. Check Supabase Row Level Security (RLS) policies

### Config Not Applying

**Check:**
- Device hasn't fetched new config yet (wait up to 10 minutes)
- Restart device to force immediate fetch
- Check `moveometer_config_history` for logged changes

### Sensor Mode Not Switching

**Serial Monitor shows:**
```
Configuring SLEEP MODE... FAILED!
```

**Possible causes:**
- Sensor doesn't support sleep mode (check model capabilities)
- Sensor needs power cycle
- Configuration mismatch

---

## 📈 Best Practices

### Configuration Management
1. **Test changes on one device** before bulk updates
2. **Document changes** in `change_reason` field
3. **Monitor config history** regularly
4. **Set `device_status` to "maintenance"** before major changes

### Data Collection
- **Fall detection**: 1000ms (1 Hz) is optimal
- **Sleep monitoring**: 1000-5000ms range is acceptable
- **Position tracking**: Requires ≤1000ms for smooth trails

### Security
- **Encrypt WiFi passwords** before storing in database
- **Use RLS policies** to restrict device access
- **Rotate API keys** periodically

---

## 🎯 Examples

### Example 1: Bedroom Sleep Monitor

```sql
UPDATE moveometers SET
    operational_mode = 'sleep',
    data_interval_ms = 2000,
    install_height_cm = 250,
    breathing_alert_min = 10,
    breathing_alert_max = 25,
    apnea_alert_threshold = 3
WHERE device_id = 'ESP32C6_001';
```

### Example 2: Bathroom Fall Detection

```sql
UPDATE moveometers SET
    operational_mode = 'fall_detection',
    data_interval_ms = 1000,
    install_height_cm = 240,
    fall_sensitivity = 7,  -- More sensitive for elderly
    position_tracking_enabled = true
WHERE device_id = 'ESP32C6_002';
```

### Example 3: Living Room Activity Monitor

```sql
UPDATE moveometers SET
    operational_mode = 'fall_detection',
    data_interval_ms = 500,  -- Faster for position tracking
    install_height_cm = 300,
    fall_sensitivity = 5,
    room_width_ft = 20.0,
    room_length_ft = 25.0
WHERE device_id = 'ESP32C6_003';
```

---

## 🔮 Future Enhancements

- [ ] Web UI for configuration management
- [ ] Mobile app configuration control
- [ ] Bulk device configuration templates
- [ ] Configuration scheduling (time-based mode switching)
- [ ] Remote firmware updates
- [ ] Configuration validation and rollback
- [ ] Device grouping and profiles

---

## 📁 File Locations

- **Database Schema**: `database/create_moveometer_tables.sql`
- **Firmware**: `pictureFrame/software/mmWave_Supabase_collector/`
- **This Guide**: `ONLINE_CONFIG_SETUP.md`

---

**Questions?** Check the forum or GitHub issues for troubleshooting help!
