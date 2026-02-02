# moveOmeter Dual Mode Setup Guide

Complete guide for running Sleep Mode and Fall Detection Mode devices with the unified dashboard.

## 🎯 Overview

Your moveOmeter system now supports **two monitoring modes**:

1. **Sleep Mode** (🛏️) - Comprehensive health monitoring, sleep analysis, vital signs
2. **Fall Detection** (🚨) - Fall detection, position tracking, residency monitoring

## 📋 Setup Steps

### Step 1: Update Supabase Database

Run this SQL in your Supabase SQL Editor to add fall detection fields:

```sql
-- Located in: database/add_fall_detection_fields.sql
-- Copy and paste the contents into Supabase SQL Editor and run
```

Or directly:
```bash
cat /Users/johnreine/Dropbox/john/2025_work/moveOmeter/database/add_fall_detection_fields.sql
```

This adds:
- `sensor_mode` column (to distinguish between modes)
- All fall detection data fields
- Indexes for performance

### Step 2: Deploy Sleep Mode Device (Bedroom)

**Location:** `pictureFrame/software/mmWave_Supabase_collector/`

1. Open `config.h` and set:
   ```cpp
   #define DEVICE_ID "bedroom_device"
   #define LOCATION "bedroom_1"
   ```

2. Upload to ESP32-C6
3. Verify data appears in Supabase with `sensor_mode = 'sleep'`

### Step 3: Deploy Fall Detection Device (Bathroom/Hallway)

**Location:** `pictureFrame/software/mmWave_FallDetection_collector/`

1. Copy and edit `config.h`:
   ```cpp
   #define WIFI_SSID "your_wifi"
   #define WIFI_PASSWORD "your_password"
   #define SUPABASE_URL "your_url"
   #define SUPABASE_ANON_KEY "your_key"
   #define SUPABASE_TABLE "mmwave_sensor_data"
   #define DEVICE_ID "bathroom_device"
   #define LOCATION "bathroom_1"
   ```

2. Upload to a second ESP32-C6
3. Verify data appears with `sensor_mode = 'fall_detection'`

### Step 4: Use the Dashboard

**Location:** `web/dashboard/`

1. Start the dashboard:
   ```bash
   cd /Users/johnreine/Dropbox/john/2025_work/moveOmeter/web/dashboard
   ./start_dashboard.sh
   ```

2. Open: http://localhost:8000

3. **Switch between modes** using the toggle at the top:
   - 🛏️ **Sleep Mode** - Shows bedroom device data
   - 🚨 **Fall Detection** - Shows bathroom device data

## 📊 Dashboard Features

### Sleep Mode View
**Metrics:**
- Heart Rate
- Respiration Rate
- Presence Detection
- In Bed Status
- Sleep Quality Score
- Apnea Events

**Charts:**
- Heart Rate over time
- Respiration Rate over time
- Presence & Movement tracking
- Sleep Quality trends

**Alerts:**
- Apnea events
- Abnormal struggle
- Out of bed during night hours
- Unattended state

### Fall Detection View
**Metrics:**
- Fall Detected (YES/NO)
- Person Present
- Motion Detected
- Position X/Y coordinates
- Time on Floor

**Charts:**
- Fall Events timeline
- Movement tracking (existence + motion)
- Position Map (scatter plot of X/Y coordinates)
- Static Residency Time

**Alerts:**
- 🚨 Fall detected
- Person on floor > 30 seconds
- Fall duration warnings

## 🏠 Recommended Deployment

### Single Room (Start Here)
- **1 device in bedroom** - Sleep Mode
- Monitor sleep quality, vital signs, and general well-being

### Two Room Setup
- **Bedroom** - Sleep Mode device
- **Bathroom** - Fall Detection device
- High-risk areas covered

### Complete Home Coverage
- **Bedroom** - Sleep Mode
- **Bathroom** - Fall Detection
- **Hallway** - Fall Detection
- **Living Room** - Sleep Mode

Each device sends data to the same Supabase table with:
- Unique `device_id`
- Unique `location`
- Appropriate `sensor_mode`

## 🔧 Configuration

### Device Config (`config.h`)
```cpp
#define DEVICE_ID "unique_name"      // Make unique per device
#define LOCATION "room_name"          // Bedroom, bathroom, etc.
#define DATA_INTERVAL 5000            // Data collection frequency (ms)
```

### Dashboard Config (`config.js`)
```javascript
deviceId: null,  // Set to null to see ALL devices, or specific ID to filter
refreshInterval: 5000,
maxDataPoints: 20
```

## 📱 Multi-Device Monitoring

To see all devices at once:

1. Edit `web/dashboard/config.js`:
   ```javascript
   deviceId: null  // Show data from all devices
   ```

2. Switch between Sleep and Fall Detection modes to see:
   - **Sleep Mode**: All bedroom/living room devices
   - **Fall Detection**: All bathroom/hallway devices

Or create multiple browser tabs, each filtered to a specific device!

## 🚨 Alert System

### Sleep Mode Alerts
- **Critical:** Apnea events, abnormal struggle
- **Warning:** Out of bed during night hours
- **Info:** Unattended state

### Fall Detection Alerts
- **Critical:** Fall detected, person on floor > 30 sec
- **Warning:** Extended fall duration
- **Info:** Static residency detected

All alerts appear in red banner at top of dashboard.

## 📊 Data Storage

Both modes store data in the same table:
```
mmwave_sensor_data
├── sensor_mode: 'sleep' or 'fall_detection'
├── device_id: unique device identifier
├── location: room/area name
├── created_at: timestamp
├── [sleep mode fields...]
└── [fall detection fields...]
```

**Storage Optimization:**
- Sleep mode fields are NULL for fall detection records
- Fall detection fields are NULL for sleep mode records
- Only relevant fields populated per mode

## 🎨 Customization

### Change Device to Different Mode

Sleep → Fall Detection:
1. Open the Arduino sketch
2. Change line 70:
   ```cpp
   sensor.configWorkMode(DFRobot_HumanDetection::eFallingMode);
   ```
3. Re-upload firmware

Fall Detection → Sleep:
1. Change to:
   ```cpp
   sensor.configWorkMode(DFRobot_HumanDetection::eSleepMode);
   ```
2. Re-upload firmware

### Add More Devices

1. Clone firmware folder
2. Edit `config.h` with unique `DEVICE_ID` and `LOCATION`
3. Upload to new ESP32-C6
4. Data automatically appears in dashboard

## 🔍 Troubleshooting

### Dashboard shows no data after mode switch
- Wait 5 seconds for new data to arrive
- Check that you have devices running in the selected mode
- Verify `sensor_mode` field in Supabase matches the mode

### Fall detection metrics show "--"
- Ensure you uploaded the Fall Detection firmware (not Sleep Mode)
- Check Serial Monitor for "Fall Detection Mode" confirmation
- Verify database has `sensor_mode = 'fall_detection'` records

### Both modes show same data
- Check `sensor_mode` field in database
- Ensure different devices are using different firmware
- Clear browser cache and refresh

## 📈 Next Steps

1. **Deploy multiple devices** across different rooms
2. **Set up notifications** for critical alerts (SMS/email via Supabase Edge Functions)
3. **Create location-based dashboards** for each room
4. **Build mobile app** for caregivers (iOS/Android)
5. **Add historical analysis** (daily/weekly/monthly reports)

## 📁 File Locations

```
moveOmeter/
├── pictureFrame/software/
│   ├── mmWave_Supabase_collector/        # Sleep Mode firmware
│   └── mmWave_FallDetection_collector/   # Fall Detection firmware
├── web/dashboard/                         # Unified dashboard
├── database/
│   └── add_fall_detection_fields.sql     # Database migration
└── DUAL_MODE_SETUP.md                    # This file
```

## 🎯 Success Checklist

- ✅ Database updated with fall detection fields
- ✅ Sleep Mode device deployed and uploading data
- ✅ Fall Detection device deployed and uploading data
- ✅ Dashboard showing data in both modes
- ✅ Mode toggle working correctly
- ✅ Alerts appearing for each mode
- ✅ Real-time updates working

You now have a complete dual-mode elderly monitoring system! 🎉
