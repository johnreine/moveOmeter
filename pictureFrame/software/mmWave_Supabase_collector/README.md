# mmWave Supabase Data Collector

Complete IoT solution for collecting mmWave sensor data and uploading to Supabase in real-time.

## Features

- ✅ Collects 40+ data fields from SEN0623 mmWave sensor
- ✅ WiFi connectivity with auto-reconnect
- ✅ Direct upload to Supabase using ESPSupabase library
- ✅ Automatic retry logic for failed uploads
- ✅ JSON formatted data
- ✅ Configurable collection intervals
- ✅ Sleep Mode optimized for elderly monitoring

## Quick Start

### 1. Install Required Libraries

Open Arduino IDE → Tools → Manage Libraries, then install:
- **ESPSupabase** by jhagas
- **DFRobot_HumanDetection** by DFRobot

### 2. Configure Your Settings

Edit `config.h` and set:

```cpp
// WiFi credentials
#define WIFI_SSID "your_wifi_network"
#define WIFI_PASSWORD "your_wifi_password"

// Supabase settings (from your Supabase dashboard)
#define SUPABASE_URL "https://xxxxx.supabase.co"
#define SUPABASE_ANON_KEY "eyJhbGc..."

// Database table name
#define SUPABASE_TABLE "mmwave_sensor_data"

// Device identification
#define DEVICE_ID "ESP32C6_001"
#define LOCATION "bedroom_1"
```

### 3. Create Supabase Table

In your Supabase dashboard, run this SQL:

```sql
CREATE TABLE mmwave_sensor_data (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Metadata
  device_id TEXT NOT NULL,
  location TEXT,
  uptime_sec INTEGER,

  -- Human Presence & Movement
  human_presence INTEGER,
  human_movement INTEGER,
  moving_range INTEGER,
  distance_cm INTEGER,

  -- Vital Signs
  heart_rate_bpm INTEGER,
  respiration_rate INTEGER,
  respiration_state INTEGER,

  -- Sleep Status
  in_bed INTEGER,
  sleep_state INTEGER,
  wake_duration_min INTEGER,
  light_sleep_min INTEGER,
  deep_sleep_min INTEGER,
  sleep_quality INTEGER,
  sleep_disturbances INTEGER,
  sleep_quality_rating INTEGER,

  -- Abnormal Events
  abnormal_struggle INTEGER,
  unattended_state INTEGER,

  -- Sleep Composite Data
  composite_presence INTEGER,
  composite_sleep_state INTEGER,
  composite_avg_respiration INTEGER,
  composite_avg_heartbeat INTEGER,
  composite_turnover_count INTEGER,
  composite_large_body_move_pct INTEGER,
  composite_minor_body_move_pct INTEGER,
  composite_apnea_events INTEGER,

  -- Sleep Statistics
  stats_sleep_quality_score INTEGER,
  stats_sleep_time_min INTEGER,
  stats_wake_duration_min INTEGER,
  stats_shallow_sleep_pct INTEGER,
  stats_deep_sleep_pct INTEGER,
  stats_time_out_of_bed_min INTEGER,
  stats_exit_count INTEGER,
  stats_turnover_count INTEGER,
  stats_avg_respiration INTEGER,
  stats_avg_heartbeat INTEGER,
  stats_apnea_events INTEGER
);

-- Create indexes for better query performance
CREATE INDEX idx_device_created ON mmwave_sensor_data(device_id, created_at DESC);
CREATE INDEX idx_location ON mmwave_sensor_data(location);
CREATE INDEX idx_presence ON mmwave_sensor_data(human_presence, created_at DESC);
```

### 4. Get Your Supabase Credentials

1. Go to your Supabase project dashboard
2. Click **Settings** → **API**
3. Copy:
   - **Project URL** → paste into `SUPABASE_URL`
   - **anon/public key** → paste into `SUPABASE_ANON_KEY`

### 5. Upload and Run

1. Connect ESP32-C6 to your computer
2. Select board: **ESP32C6 Dev Module**
3. Select port
4. Upload the sketch
5. Open Serial Monitor at 115200 baud

## Expected Output

```
=================================
mmWave Supabase Data Collector
=================================
Connecting to WiFi: MyNetwork... CONNECTED!
IP Address: 192.168.1.100
Initializing Supabase... SUCCESS!
Initializing sensor (this takes ~10 seconds)... SUCCESS!
Configuring Sleep Mode... SUCCESS!
=================================
System ready! Collecting data...

Data collected:
{"device_id":"ESP32C6_001","location":"bedroom_1",...}
Uploading to Supabase... SUCCESS!
```

## Data Fields Reference

### Vital Signs
- **heart_rate_bpm**: Heart rate in beats per minute (0-255)
- **respiration_rate**: Breaths per minute (0-255)
- **respiration_state**: 1=normal, 2=too fast, 3=too slow, 4=none

### Sleep Metrics
- **in_bed**: 0=out of bed, 1=in bed
- **sleep_state**: Current sleep state code
- **sleep_quality**: Real-time sleep quality score
- **stats_sleep_quality_score**: Overall sleep quality (cumulative)
- **stats_sleep_time_min**: Total sleep duration in minutes
- **stats_shallow_sleep_pct**: Light sleep as percentage of total
- **stats_deep_sleep_pct**: Deep sleep as percentage of total

### Movement Detection
- **human_presence**: 0=absent, 1=present
- **human_movement**: Movement intensity (0-100)
- **moving_range**: Movement area coverage (0-100)
- **distance_cm**: Distance to detected person in centimeters

### Abnormal Events
- **abnormal_struggle**: Detected struggle or distress
- **composite_apnea_events**: Breathing pause events (sleep apnea)
- **stats_apnea_events**: Total apnea events (cumulative)
- **unattended_state**: Person has left the monitored area

### Sleep Analysis
- **composite_turnover_count**: Number of position changes
- **composite_large_body_move_pct**: Large movements as percentage
- **composite_minor_body_move_pct**: Small movements as percentage
- **stats_exit_count**: Times person got out of bed
- **stats_time_out_of_bed_min**: Total time spent out of bed

## Configuration Options

### Data Collection Interval

In `config.h`, adjust:
```cpp
#define DATA_INTERVAL 5000  // milliseconds (5 seconds default)
```

Recommendations:
- Real-time monitoring: 1000-5000 ms
- Battery optimization: 30000-60000 ms
- Long-term trends: 300000-900000 ms (5-15 minutes)

### Retry Settings

```cpp
#define RETRY_ATTEMPTS 3     // Number of upload retries
#define RETRY_DELAY 2000     // Delay between retries (ms)
```

## Troubleshooting

### WiFi Connection Failed
- Verify SSID and password in `config.h`
- Check that ESP32-C6 is within WiFi range
- Ensure 2.4GHz WiFi (ESP32-C6 doesn't support 5GHz)

### Supabase Upload Failed (HTTP 401)
- Check that `SUPABASE_ANON_KEY` is correct
- Verify table name matches `SUPABASE_TABLE`
- Check Supabase Row Level Security policies (disable for testing)

### Supabase Upload Failed (HTTP 404)
- Table name doesn't exist
- Check `SUPABASE_TABLE` spelling in `config.h`

### Sensor Initialization Failed
- Check wiring connections
- Verify 5V power supply
- Wait 10 seconds for sensor startup

### Data Looks Wrong
- Sensor needs ~30-60 seconds after startup to calibrate
- Movement data is only accurate when person is in detection range
- Sleep statistics accumulate over time (won't show immediately)

## Security Best Practices

### Protect Your Credentials

**IMPORTANT**: Never commit `config.h` to public repositories!

Add to `.gitignore`:
```
config.h
```

### Supabase Row Level Security

For production, enable RLS policies in Supabase:

```sql
-- Allow inserts from authenticated devices only
ALTER TABLE mmwave_sensor_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow device inserts"
ON mmwave_sensor_data
FOR INSERT
WITH CHECK (auth.role() = 'anon');

-- Allow reads for authenticated users
CREATE POLICY "Allow authenticated reads"
ON mmwave_sensor_data
FOR SELECT
USING (auth.role() = 'authenticated');
```

## Next Steps

1. **Multiple Devices**: Clone and configure unique `DEVICE_ID` for each unit
2. **Data Visualization**: Build dashboards in Supabase or connect to Grafana
3. **Alerts**: Create edge functions to send notifications for abnormal events
4. **Battery Operation**: Add deep sleep between readings for battery power
5. **OTA Updates**: Implement over-the-air firmware updates

## Hardware Requirements

- ESP32-C6 Feather (or compatible board)
- DF Robot SEN0623 (C1001 mmWave sensor)
- 5V power supply (USB or dedicated)
- WiFi network (2.4GHz)

## Libraries Used

- **ESPSupabase** - [GitHub](https://github.com/jhagas/ESPSupabase)
- **DFRobot_HumanDetection** - [GitHub](https://github.com/DFRobot/DFRobot_HumanDetection)

## License

This is part of the moveOmeter IoT elderly monitoring project.

## Support

For issues or questions, refer to:
- [ESPSupabase Documentation](https://github.com/jhagas/ESPSupabase)
- [SEN0623 Wiki](https://wiki.dfrobot.com/SKU_SEN0623_C1001_mmWave_Human_Detection_Sensor)
