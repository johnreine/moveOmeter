# DPS310 Pressure Sensor Test

Simple test program to monitor pressure changes in real-time and verify door detection is working.

## Setup

1. **Connect DPS310 sensor to ESP32-C6:**
   ```
   DPS310 → ESP32-C6 Feather
   VIN    → 3.3V
   GND    → GND
   SCL    → GPIO7
   SDA    → GPIO6
   ```

2. **Install Arduino library:**
   - Arduino IDE → Tools → Manage Libraries
   - Search: "Adafruit DPS310"
   - Install: "Adafruit DPS310 Library" by Adafruit

3. **Upload sketch:**
   - Open `DPS310_pressure_test.ino`
   - Select board: "Adafruit Feather ESP32-C6"
   - Upload to board

4. **Open Serial Monitor:**
   - Set baud rate: 115200
   - Watch the pressure readings

## What to Look For

### Startup
You should see:
```
=================================
DPS310 Pressure Sensor Test
=================================

Initializing DPS310 sensor... SUCCESS!
Initial pressure: 1013.45 hPa
Initial temperature: 23.15 °C

Monitoring pressure changes...
Try opening/closing a door nearby!
```

### During Normal Operation
```
Time(ms)  | Pressure (hPa) | Change (hPa) | Max Change | Events | Status
----------|----------------|--------------|------------|--------|--------
1234      | 1013.450       | +0.002       | 0.002      | 0      | stable
1334      | 1013.451       | +0.001       | 0.002      | 0      | stable
1434      | 1013.452       | +0.001       | 0.002      | 0      | stable
```

### When You Open/Close a Door
You should see a spike:
```
2234      | 1013.450       | +0.002       | 0.002      | 0      | stable
2334      | 1013.650       | +0.200       | 0.200      | 0      | ~ pressure changing
2434      | 1013.850       | +0.200       | 0.200      | 0      | ~ pressure changing
2534      | 1014.250       | +0.400       | 0.400      | 1      | 🚪 DOOR EVENT!
2634      | 1014.350       | +0.100       | 0.400      | 1      | ~ pressure changing
2734      | 1014.320       | -0.030       | 0.400      | 1      | stable
```

## Troubleshooting

### "FAILED!" on startup
- Check wiring connections
- Verify I2C address is 0x77 (default)
- Try different I2C address: `dps.begin_I2C(0x76)`

### No pressure changes when opening door
- Move sensor closer to door (same room)
- Try a larger door (exterior door works better than closet)
- Adjust threshold in code (line 15):
  ```cpp
  #define DOOR_EVENT_THRESHOLD 0.2  // Lower = more sensitive
  ```

### Too many false events
- Increase threshold:
  ```cpp
  #define DOOR_EVENT_THRESHOLD 0.4  // Higher = less sensitive
  ```
- Check for HVAC interference
- Ensure sensor is stable (not moving/vibrating)

## Expected Pressure Changes

| Event                  | Typical Change |
|------------------------|----------------|
| Door open/close        | 0.3 - 1.0 hPa  |
| Window open            | 0.2 - 0.5 hPa  |
| HVAC turn on           | 0.1 - 0.3 hPa  |
| Normal fluctuation     | < 0.05 hPa     |

## Next Steps

Once you verify the sensor is detecting door events:
1. Note the typical pressure change values
2. Adjust `DOOR_EVENT_THRESHOLD` if needed
3. Upload the main firmware with the tuned threshold
4. Check database for door_event data
