# moveOmeter App Version History

## Version Numbering
Format: `MAJOR.MINOR.PATCH+BUILD`
- MAJOR: Breaking changes or major new features
- MINOR: New features, significant improvements
- PATCH: Bug fixes, minor improvements
- BUILD: Incremental build number

## Versions

### v1.1.2+7 (2026-04-13)
- **Bluetooth Permissions Fixed:**
  - Added BLUETOOTH_SCAN permission (Android 12+)
  - Added BLUETOOTH_CONNECT permission (Android 12+)
  - Added BLUETOOTH_ADVERTISE permission (Android 12+)
  - Added backward compatibility for older Android versions
  - BLE device scanning now works properly
  - Can now discover and provision moveOmeter devices

### v1.1.1+6 (2026-04-13)
- **UI Improvements:**
  - Version number now displayed on login page (below subtitle)
  - Easy verification that latest version is installed
- **Android Network Fixes:**
  - Added network security configuration for better SSL/TLS handling
  - Explicitly configured trust for Supabase domain
  - Disabled cleartext traffic for security

### v1.1.0+5 (2026-04-13)
- **Network Connectivity Fixes:**
  - Added network connectivity check before Supabase initialization
  - Added 500ms network stabilization delay (fixes Android DNS issues)
  - Increased connection timeouts (15s for init, 8s for auto-login)
  - Added ACCESS_NETWORK_STATE permission
  - Enhanced logging with emoji markers (🌐📡🔗✅⚠️❌)
- **UI Improvements:**
  - Version number now displayed in app bar (top right)
  - Better error messages for network failures

### v1.0.0+1 (Initial Release)
- Initial release with:
  - User authentication and auto-login
  - Houses and devices management
  - Analytics tracking
  - Secure credential storage
  - WiFi provisioning for devices
  - Bluetooth device discovery

## How to Update Version

**Before each release build:**

1. Edit `pubspec.yaml` and increment version:
   ```yaml
   version: 1.1.0+5  # Change this
   ```

2. Update this file (VERSION_HISTORY.md) with changes

3. Build APK:
   ```bash
   flutter build apk --release
   ```

4. Upload to server:
   ```bash
   scp build/app/outputs/flutter-apk/app-release.apk root@moveometer.com:/var/www/moveometer/moveometer.apk
   ```

5. Verify version displays correctly in app after installation
