# BLE Provisioning - Error Handling & Edge Cases

## Error Handling Added

### 1. Input Validation
**Location:** `BLEProvisioningService.provisionDevice()`

- **Empty SSID**: Prevents sending empty network names
- **SSID too long**: Max 32 characters (WiFi spec limit)
- **Password too short**: Min 8 characters (WiFi WPA2 requirement)
- **Password too long**: Max 63 characters (WiFi spec limit)
- **Payload size**: Max 200 bytes to stay within BLE MTU limits

### 2. Connection Failures
**Location:** `BLEProvisioningService.provisionDevice()`

**Handled cases:**
- **Already connected**: Disconnect first, wait 500ms, retry
- **Connection timeout**: 3 retry attempts with exponential backoff (1s, 2s, 3s)
- **Connection state mismatch**: Verify connection after connect() call
- **Helpful error**: "Make sure the device is nearby and not already connected to another phone"

### 3. Service Discovery Failures
**Location:** `BLEProvisioningService.provisionDevice()`

**Handled cases:**
- **Discovery timeout**: 10-second timeout with clear error
- **No services found**: "This may not be a valid moveOmeter device"
- **Service not found**: "This device may be running old firmware. Please update the device firmware and try again."
- **Characteristic missing write property**: Check properties before attempting write

### 4. Data Transfer Failures
**Location:** `BLEProvisioningService.provisionDevice()`

**Handled cases:**
- **Write failure**: 3 retry attempts with 500ms backoff
- **Notification setup failure**: Graceful error with context
- **Invalid response JSON**: Decode errors caught, raw response logged
- **Response timeout**: 15-second timeout (device may have rebooted successfully)
- **Device error response**: Parse and display device-reported errors

### 5. Bluetooth Permission Issues
**Location:** `ScanDevicesPage._startScan()`

**Handled cases:**
- **Permission denied**: Clear message to grant in Settings
- **Permanently denied**: Specific instruction to enable in Settings > moveOmeter
- **iOS < 13 compatibility**: Catch and ignore permission_handler exceptions on old iOS

### 6. Bluetooth State Issues
**Location:** `ScanDevicesPage._startScan()`

**Handled cases:**
- **BLE not supported**: "Bluetooth Low Energy is not supported on this device"
- **Bluetooth off**: "Please turn on Bluetooth in Settings and try again"
- **Unauthorized**: "Please enable Bluetooth permissions in Settings"
- **Unknown state**: 5-second timeout when checking adapter state
- **Adapter state check timeout**: Handle gracefully with unknown state

### 7. Scan Failures
**Location:** `ScanDevicesPage._startScan()`

**Handled cases:**
- **No devices found**: Show helpful message about blue LED indicator
- **Scan already running**: Stop existing scan before starting new one
- **15-second scan timeout**: Automatic timeout built into scan

### 8. User-Friendly Error Messages
**Location:** `WiFiConfigPage._provision()`

**Pattern matching for common errors:**
- Connection issues → "Make sure you're close to the device"
- Timeout → "Check your devices list to see if it appeared" (may have succeeded)
- Permission issues → "Go to Settings > moveOmeter and enable Bluetooth"
- Old firmware → "Contact support"
- Password errors → "Check that your password is correct (8-63 characters)"
- SSID errors → "Check that your network name is correct (1-32 characters)"

---

## Edge Cases Covered

### 1. Race Conditions

**Device disconnects during provisioning:**
- Finally block ensures cleanup
- Disconnect timeout prevents hanging
- Subscription cancelled even on error

**Multiple rapid scans:**
- Stop existing scan before starting new one
- Clear device list on each scan start

**User navigates away mid-provision:**
- `mounted` checks before setState
- Subscription cleanup in finally block

### 2. Network Edge Cases

**Weak BLE signal:**
- 3 connection retries with backoff
- 3 write retries with backoff
- 15-second response timeout (generous for weak signal)

**Device out of range:**
- Connection timeout with clear error
- Suggestion to move closer

**Interference from other BLE devices:**
- Service UUID filtering
- Name prefix filtering ("moveOmeter-")

### 3. Device State Edge Cases

**Device already provisioned:**
- Will still advertise if config.h has placeholders
- If already has WiFi, BLE won't start (firmware check)

**Device reboots before sending success response:**
- 15-second timeout
- Error suggests checking devices list (may have worked)

**Device low battery:**
- No specific handling (hardware limitation)
- Connection failures will trigger retry logic

**Multiple devices nearby:**
- List shows all discovered devices
- User selects specific one by name

### 4. User Input Edge Cases

**Special characters in password:**
- UTF-8 encoding handles all characters
- JSON escaping handled by jsonEncode()

**Leading/trailing spaces in SSID:**
- `.trim()` removes spaces before sending

**Hidden SSID (user manually enters):**
- Works fine, no special handling needed

**5GHz vs 2.4GHz network:**
- ESP32-C6 supports both
- No app-side validation needed

### 5. Platform Differences

**iOS vs Android BLE behavior:**
- iOS requires Info.plist permissions (added)
- Android requires runtime permissions (handled)
- permission_handler abstracts differences

**iOS < 13:**
- permission_handler may throw on old iOS
- Catch and ignore, Bluetooth still works

**Different BLE MTU sizes:**
- Conservative 200-byte payload limit
- Well below typical 512-byte MTU

### 6. Firmware/App Version Mismatch

**Old firmware (no BLE service):**
- "Provisioning service not found" error
- Suggests firmware update

**Different UUIDs:**
- Would fail service discovery
- Error clearly states service not found

**Different JSON format:**
- Parse errors caught
- Raw response logged for debugging

---

## Failure Prediction & Mitigation

### High Probability Failures

| Failure | Probability | Mitigation |
|---------|-------------|------------|
| User enters wrong password | High | Retry button in error dialog, password visibility toggle |
| Bluetooth permission denied | Medium | Clear instructions to enable in Settings |
| Device out of range | Medium | Connection retry with suggestion to move closer |
| Weak BLE signal | Medium | 3 connection retries, 3 write retries, generous timeouts |
| Device already connected | Low-Med | Auto-disconnect existing connection before provisioning |

### Low Probability Failures

| Failure | Probability | Mitigation |
|---------|-------------|------------|
| BLE not supported | Very Low | Check FlutterBluePlus.isSupported, clear error message |
| Payload too large | Very Low | 200-byte limit check before send |
| Invalid JSON response | Very Low | Try-catch on decode, log raw response |
| Service UUID mismatch | Very Low | Would be caught in service discovery |

### Unhandled Failures (Acceptable)

| Failure | Why Unhandled | User Workaround |
|---------|---------------|-----------------|
| Device hardware failure | Can't detect from app | Power cycle device |
| Device low battery | No battery level in BLE service | Charge device |
| Router rejects connection | Can't know until device tries | User fixes router settings |
| Network congestion | Beyond app control | User waits, retries later |

---

## Testing Recommendations

### Happy Path
1. ✅ Normal provisioning flow
2. ✅ Device appears in list after reboot

### Error Paths to Test
1. ✅ Wrong WiFi password → should clear stored creds and re-enter BLE mode
2. ✅ Bluetooth off → clear error message
3. ✅ Permission denied → instructions to enable
4. ✅ Device out of range → timeout with suggestion
5. ✅ No devices found → helpful message about LED
6. ✅ Network name too long → validation error
7. ✅ Password too short → validation error
8. ✅ Navigate away mid-provision → clean cancellation

### Edge Cases to Test
1. ✅ Provision while another device connected
2. ✅ Rapid scan start/stop
3. ✅ Special characters in password
4. ✅ Hidden SSID
5. ✅ Multiple devices nearby

---

## User Experience Improvements

1. **Progressive disclosure**: Simple form → detailed errors only on failure
2. **Contextual help**: Suggestions appear based on error type
3. **Retry logic**: Automatic retries for transient failures
4. **Clear next steps**: "Check your devices list" if timeout (may have worked)
5. **No jargon**: "Service UUID" → "This device may be running old firmware"
6. **Keyboard handling**: Auto-dismiss keyboard before provisioning

---

## Monitoring & Logging (Future)

For production, consider adding:
- Analytics events for each error type
- Success/failure rates by error category
- Average provisioning time
- BLE connection retry rates

This data helps identify:
- Common failure modes
- Firmware bugs
- UX friction points
- Hardware reliability issues
