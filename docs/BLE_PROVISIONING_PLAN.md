# BLE Provisioning Implementation Plan

## Overview
Add Bluetooth Low Energy (BLE) provisioning to allow users to configure WiFi credentials for new moveOmeter devices directly from the mobile app, without needing to hardcode credentials in firmware.

## Goals
- Zero-touch WiFi setup for end users
- Secure credential transfer via BLE
- Simple in-app flow: scan → select device → enter WiFi → done
- Works on both iOS and Android

---

## Architecture

### Components
1. **ESP32-C6 Firmware** - BLE GATT server advertising provisioning service
2. **Flutter App** - BLE client that scans, connects, and sends credentials
3. **NVS Storage** - Persistent WiFi credential storage on device

### Data Flow
```
User enters WiFi creds in app
    ↓
App sends JSON via BLE write: {"ssid":"MyNetwork","password":"secret123"}
    ↓
ESP32-C6 receives, validates, saves to NVS
    ↓
Device reboots, connects to WiFi
    ↓
Device registers with Supabase (existing flow)
    ↓
Appears in app's device list
```

---

## Implementation Steps

### Phase 1: Firmware BLE Service (1-2 hours)

#### 1.1 Add BLE Dependencies
- Include `BLEDevice.h`, `BLEServer.h`, `BLEUtils.h`, `Preferences.h`
- Define UUIDs for service and characteristic
  - Service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b` (custom)
  - Characteristic UUID: `beb5483e-36e1-4688-b7f5-ea07361b26a8` (custom)

#### 1.2 Create BLE Server
- Initialize BLE on boot if WiFi credentials not configured
- Advertise as "moveOmeter-XXXXXX" (last 6 chars of MAC)
- Create GATT service with write-only characteristic

#### 1.3 Credential Handling
- Receive JSON payload: `{"ssid":"...", "password":"..."}`
- Validate JSON structure
- Save to NVS using `Preferences` library:
  ```cpp
  preferences.begin("wifi", false);
  preferences.putString("ssid", ssid);
  preferences.putString("password", password);
  preferences.end();
  ```
- Send success response back to app
- Reboot device to apply new WiFi config

#### 1.4 Boot Logic Update
- On startup, check NVS for WiFi credentials
- If found: connect to WiFi (existing flow)
- If not found: start BLE provisioning mode (LED blinks blue)
- Add factory reset: hold button 10s to clear WiFi creds and restart BLE

#### Files to modify:
- `mmWave_Supabase_collector.ino` - add BLE init, credential handling
- `config.h` - remove hardcoded WiFi credentials (make them runtime-only)

---

### Phase 2: Flutter App BLE Client (1-2 hours)

#### 2.1 Add Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_blue_plus: ^1.32.0
  permission_handler: ^11.0.0
```

#### 2.2 Create Setup Flow Pages

**New files:**
- `lib/pages/add_device_page.dart` - Entry point, requests BLE permissions
- `lib/pages/scan_devices_page.dart` - Scans for nearby devices, shows list
- `lib/pages/wifi_config_page.dart` - WiFi credential entry form
- `lib/services/ble_provisioning_service.dart` - BLE communication logic

#### 2.3 BLE Provisioning Service
```dart
class BLEProvisioningService {
  Future<List<BluetoothDevice>> scanForDevices() async {
    // Scan for devices with our service UUID
    // Return list of nearby moveOmeters
  }

  Future<void> provisionDevice(
    BluetoothDevice device,
    String ssid,
    String password,
  ) async {
    // Connect to device
    // Find characteristic
    // Write JSON: {"ssid":"...","password":"..."}
    // Await success response
    // Disconnect
  }
}
```

#### 2.4 UI Flow
1. **Add Device Button** (on DevicesPage)
   - FloatingActionButton "+"
   - Opens AddDevicePage

2. **AddDevicePage**
   - Request BLE permissions (iOS: Info.plist, Android: AndroidManifest.xml)
   - "Scan for Devices" button → ScanDevicesPage

3. **ScanDevicesPage**
   - Show scanning indicator
   - List discovered devices: "moveOmeter-A1B2C3"
   - Tap device → WifiConfigPage

4. **WifiConfigPage**
   - SSID text field (can pre-fill current network on iOS)
   - Password text field (obscured)
   - "Connect" button
   - Progress indicator during provisioning
   - Success → navigate back to DevicesPage (device will appear after ~10s)
   - Error → show error message, allow retry

#### 2.5 Permissions Setup
**iOS (`ios/Runner/Info.plist`):**
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth is required to set up new moveOmeter devices</string>
```

**Android (`android/app/src/main/AndroidManifest.xml`):**
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

---

### Phase 3: Testing & Edge Cases (30-60 min)

#### 3.1 Happy Path Testing
- Factory-fresh device (no WiFi configured)
- App scans, finds device
- User enters credentials
- Device connects to WiFi
- Device appears in Supabase/app

#### 3.2 Edge Cases to Handle
- **Invalid credentials**: Device tries to connect, fails, re-enters BLE mode after 30s
- **Out of range**: App shows timeout if BLE write fails
- **Wrong password**: Device can't connect to WiFi, re-advertises BLE
- **Network not found**: Same as wrong password
- **Multiple devices**: User can provision multiple devices in sequence
- **Already provisioned**: If device already has WiFi, BLE is disabled (or only enabled via factory reset)

#### 3.3 Security Considerations
- BLE pairing: optional, adds complexity but encrypts credentials
- For v1: unencrypted BLE (credentials only sent when user is within 10m)
- For v2: add BLE pairing/bonding for encryption

---

## Success Criteria
- [ ] Factory-fresh device boots into BLE provisioning mode (LED blinks blue)
- [ ] App can discover device via BLE scan
- [ ] App can send WiFi credentials to device
- [ ] Device saves credentials to NVS
- [ ] Device reboots and connects to WiFi
- [ ] Device registers with Supabase and appears in app
- [ ] Factory reset clears credentials and restarts BLE mode
- [ ] Works on both iOS and Android

---

## Future Enhancements (Post-MVP)
- BLE pairing for encrypted credential transfer
- Pre-fill WiFi SSID from phone's current network
- QR code option (scan moveOmeter serial number to auto-pair)
- Batch provisioning (configure multiple devices at once)
- WiFi network strength indicator during setup
- Fallback: web-based provisioning (SoftAP) if BLE fails

---

## Timeline Estimate
- **Phase 1 (Firmware)**: 1-2 hours
- **Phase 2 (App)**: 1-2 hours
- **Phase 3 (Testing)**: 0.5-1 hour
- **Total**: 2.5-5 hours (depends on testing iterations)

---

## Next Steps
1. Review plan with user
2. Start with Phase 1 (firmware) - can test with BLE scanner app before building Flutter UI
3. Proceed to Phase 2 (app)
4. Test end-to-end (Phase 3)
5. Deploy to production

---

## Open Questions
- Should we support BLE pairing/encryption in v1, or add later?
- What should the factory reset mechanism be? (button hold duration, sequence)
- Should we show WiFi signal strength in the app during setup?
- Do we want to support multiple WiFi networks (home + backup)?
