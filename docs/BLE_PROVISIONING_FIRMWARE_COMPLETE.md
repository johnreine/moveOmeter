# BLE Provisioning - Firmware Implementation Complete

## Files Created
1. **ble_provisioning.h** - Header with BLE service definitions and callbacks
2. **ble_provisioning.cpp** - Implementation of BLE provisioning logic

## Files Modified
1. **mmWave_Supabase_collector.ino**
   - Added `#include "ble_provisioning.h"`
   - Modified `connectWiFi()` to try NVS credentials first, fallback to config.h
   - Modified `setup()` to detect missing WiFi config and enter BLE mode

## How It Works

### Boot Flow
```
Device boots
    ↓
Check NVS for WiFi credentials
    ↓
┌─────────────────┐
│ Has credentials?│
└────┬────────────┘
     │
     ├─ YES → Connect to WiFi (normal operation)
     │
     └─ NO (and config.h has placeholders)
          ↓
        Start BLE Provisioning Mode
          ↓
        Flash LED blue (blinking)
          ↓
        Advertise as "moveOmeter-XXXXXX"
          ↓
        Wait for app to send credentials
```

### BLE Provisioning Flow
```
App connects via BLE
    ↓
App writes JSON: {"ssid":"MyWiFi","password":"secret123"}
    ↓
Firmware validates JSON
    ↓
┌─────────┐
│ Valid?  │
└────┬────┘
     │
     ├─ YES → Save to NVS
     │         ↓
     │       Send success response
     │         ↓
     │       Reboot device
     │         ↓
     │       Connect to WiFi
     │
     └─ NO → Send error response
               ↓
             Stay in BLE mode
```

### NVS Storage
- **Namespace**: `wifi_config`
- **Keys**:
  - `ssid` (String, max 32 chars)
  - `password` (String, 8-63 chars)

### BLE UUIDs
- **Service**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Characteristic**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`

### Device Naming
- Format: `moveOmeter-XXXXXX`
- XXXXXX = last 3 bytes of MAC address (hex)
- Example: `moveOmeter-A1B2C3`

## JSON Protocol

### Request (App → Device)
```json
{
  "ssid": "MyNetwork",
  "password": "secret123"
}
```

### Response (Device → App)

**Success:**
```json
{
  "status": "success",
  "message": "WiFi configured. Device will reboot."
}
```

**Error (invalid JSON):**
```json
{
  "status": "error",
  "message": "Invalid JSON"
}
```

**Error (missing fields):**
```json
{
  "status": "error",
  "message": "Missing ssid or password"
}
```

**Error (invalid SSID length):**
```json
{
  "status": "error",
  "message": "SSID must be 1-32 characters"
}
```

**Error (invalid password length):**
```json
{
  "status": "error",
  "message": "Password must be 8-63 characters"
}
```

## Factory Reset

To add factory reset (button hold 10s):
```cpp
// In loop(), check button state
if (digitalRead(BUTTON_PIN) == LOW) {
  unsigned long pressStart = millis();
  while (digitalRead(BUTTON_PIN) == LOW) {
    if (millis() - pressStart > 10000) {
      clearWiFiCredentials();
      ESP.restart();
    }
  }
}
```

## Testing with nRF Connect (Before Building App)

1. Download "nRF Connect" app (iOS/Android)
2. Flash firmware with placeholder WiFi credentials
3. Device boots into BLE mode (blue blinking LED)
4. Open nRF Connect → Scan → find "moveOmeter-XXXXXX"
5. Connect → expand service `4fafc201...`
6. Write to characteristic `beb5483e...`:
   ```
   {"ssid":"YourWiFi","password":"YourPassword"}
   ```
7. Device should reboot and connect to WiFi

## Next Steps
- Test firmware with nRF Connect
- Build Flutter app BLE client (Task #2)
- End-to-end testing (Task #3)

## Dependencies Added
- ESP32 BLE Arduino (built-in with ESP32 board package)
- ArduinoJson (for JSON parsing)
- Preferences (built-in with ESP32 core)

## Code Stats
- **ble_provisioning.h**: ~125 lines
- **ble_provisioning.cpp**: ~120 lines
- **mmWave_Supabase_collector.ino**: ~50 lines modified
- **Total**: ~300 lines
