# DPS310 Pressure Sensor Setup for Door Detection

## Hardware Setup

**Sensor:** Adafruit DPS310 Barometric Pressure Sensor
**Connection:** I2C at address 0x77

### Wiring (ESP32-C6 Feather)
```
DPS310 → ESP32-C6 Feather
VIN    → 3.3V
GND    → GND
SCL    → SCL (GPIO7)
SDA    → SDA (GPIO6)
```

## Software Setup

### 1. Install Arduino Library

In Arduino IDE → Tools → Manage Libraries:
- Search for: **Adafruit DPS310**
- Install: "Adafruit DPS310 Library" by Adafruit

### 2. Run Database Migration

In Supabase SQL Editor, run:
```bash
/database/add_pressure_sensor.sql
```

This adds three columns:
- `air_pressure_hpa` - Current pressure reading
- `pressure_change_hpa` - Max change in interval
- `door_events` - Count of detected events

### 3. Upload Firmware

1. Open `mmWave_Supabase_collector.ino`
2. Verify DPS310 library is included
3. Upload to ESP32-C6
4. Open Serial Monitor (115200 baud)

## How It Works

**Sampling Rate:** 10 Hz (every 100ms)

**Event Detection:**
- Threshold: 0.3 hPa pressure change
- When a door opens/closes, air rushes in/out causing rapid pressure change
- System detects change and increments counter

**Data Upload:**
Every 20 seconds:
- `air_pressure_hpa`: Current pressure (e.g., 1013.25 hPa)
- `pressure_change_hpa`: Largest change detected (e.g., 0.5 hPa)
- `door_events`: How many times threshold was exceeded (e.g., 2)

## Expected Output

```
Initializing DPS310 pressure sensor... SUCCESS!
Initial pressure: 1013.45 hPa

[DATA COLLECTION] Movement: 0, Presence: 1
[DOOR EVENT] Pressure change: 0.45 hPa (1013.45 -> 1013.90)

--- JSON DATA ---
{
  "device_id":"ESP32C6_001",
  ...
  "air_pressure_hpa":1013.90,
  "pressure_change_hpa":0.45,
  "door_events":1
}
-----------------
```

## Testing Door Detection

1. **Baseline:** Let sensor stabilize for 1 minute
2. **Test:** Open a door near the sensor
3. **Observe:** Serial Monitor should show `[DOOR EVENT]` message
4. **Verify:** Check Supabase table - `door_events` should increment

## Tuning

### Adjust Sensitivity

In firmware, change threshold:
```cpp
#define DOOR_EVENT_THRESHOLD 0.3  // Default: 0.3 hPa
```

**Higher value** → Less sensitive (only large pressure changes)
**Lower value** → More sensitive (small pressure changes detected)

Recommended range: 0.2 - 0.5 hPa

### Typical Pressure Changes

- **Door open/close:** 0.3 - 1.0 hPa
- **Window open:** 0.2 - 0.5 hPa
- **HVAC turn on:** 0.1 - 0.3 hPa
- **Weather change:** 0.01 - 0.1 hPa/hour
- **Normal fluctuation:** < 0.05 hPa

## Dashboard Integration (TODO)

Future enhancements:
- Display current air pressure
- Show door events count
- Timeline of door events
- Alert on unusual door activity

## Troubleshooting

**"DPS310 FAILED" on startup:**
- Check wiring (I2C connections)
- Verify address with I2C scanner (should be 0x77)
- Try different I2C address: `dps.begin_I2C(0x76)`

**No door events detected:**
- Increase sampling: change threshold to 0.2 hPa
- Verify door is close to sensor (within same room)
- Check Serial Monitor for pressure readings

**Too many false positives:**
- Decrease sensitivity: change threshold to 0.4-0.5 hPa
- Ensure sensor is stable (not moving/vibrating)
- Check for HVAC interference

## Technical Details

**DPS310 Specifications:**
- Pressure range: 300 - 1200 hPa
- Accuracy: ±0.002 hPa (±2 cm altitude)
- Resolution: 0.006 hPa
- Sample rate: Up to 128 Hz
- I2C addresses: 0x77 (default) or 0x76

**Sample Rate:** 10 Hz (configured in firmware)
- Fast enough to catch door transients (~500ms)
- Not overwhelming ESP32-C6 or data upload

**Data Retention:** Same as sensor data (device_timestamp indexed)

---

**Ready to test?** Upload firmware and watch Serial Monitor for `[DOOR EVENT]` messages!
