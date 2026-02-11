# moveOmeter Project - Complete Status Documentation

**Last Updated:** February 10, 2026
**Project Status:** Active Development - Core Features Complete, Testing & Optimization Phase

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Completed Features](#completed-features)
4. [Current Capabilities](#current-capabilities)
5. [Recent Major Updates](#recent-major-updates)
6. [Known Issues & Limitations](#known-issues--limitations)
7. [Testing Status](#testing-status)
8. [Deployment Information](#deployment-information)
9. [Documentation Index](#documentation-index)

> **🤖 For AI Assistants:** See [AI_AGENT_GUIDE.md](./AI_AGENT_GUIDE.md) for comprehensive technical context, implementation patterns, and decision-making guidelines.

---

## Project Overview

**moveOmeter** is a comprehensive IoT elderly monitoring system that uses mmWave radar technology to provide non-invasive, privacy-preserving health and activity monitoring.

### Core Purpose
Monitor seniors in their homes to track:
- Movement patterns and activity levels
- Sleep quality and duration
- Presence detection and fall alerts
- Vital signs (heart rate, respiration)
- Daily activity metrics for caretaker oversight

### Key Differentiators
- **Privacy-first:** Uses radar technology (no cameras or wearables)
- **Non-invasive:** No user interaction required
- **Real-time:** Live data streaming and alerts
- **Multi-role:** Supports admins, employees, caretakers, and residents
- **Scalable:** Designed for 100 to 5M+ users

---

## System Architecture

### Hardware Layer
**ESP32-C6 Feather + DFRobot SEN0623 mmWave Sensor**

```
┌─────────────────────────────────────────┐
│   ESP32-C6 Feather                      │
│   ├─ WiFi 2.4GHz (internet connection)  │
│   ├─ GPIO16 (TX) → mmWave RX            │
│   ├─ GPIO17 (RX) → mmWave TX            │
│   ├─ USB Serial (115200 debugging)      │
│   └─ OTA Update Capable                 │
└─────────────────────────────────────────┘
         ↓ WiFi Upload
┌─────────────────────────────────────────┐
│   DFRobot SEN0623 mmWave Sensor         │
│   ├─ Human presence detection           │
│   ├─ Movement & distance tracking       │
│   ├─ Vital signs (heart rate, respir.)  │
│   ├─ Sleep monitoring                   │
│   ├─ Fall detection                     │
│   └─ UART communication (9600 baud)     │
└─────────────────────────────────────────┘
```

**Firmware:**
- Platform: Arduino (C++)
- Current Version: 1.0.0
- Location: `/pictureFrame/software/mmWave_Supabase_collector/`

**Key Features:**
- Dual collection modes (Quick/Medium) - configurable remotely
- Smart keep-alive (30s when no presence, full data when presence detected)
- Periodic config checks (60s) to sync settings from cloud
- OTA firmware update capability (1-hour check interval)
- Device timestamp tracking for accurate time series data
- WiFi auto-reconnect with retry logic
- Fall detection with 30s monitoring even when no presence

### Backend Layer
**Supabase (PostgreSQL + Auth + Storage + Realtime)**

**Database Tables:**
```
moveometers (device registry)
  ├─ device_id, location, firmware_version
  ├─ data_collection_mode (quick/medium)
  ├─ ota_check_interval_ms, ota_status
  └─ last_ota_check, last_ota_update

mmwave_sensor_data (time series data)
  ├─ 40+ sensor fields
  ├─ device_timestamp (when recorded)
  ├─ created_at (when uploaded)
  └─ data_type (keep_alive vs full)

user_profiles (authentication)
  ├─ id, email, full_name
  ├─ role (admin/employee/caretaker/caretakee)
  ├─ is_active, mfa_enabled
  └─ last_login

device_access (permissions)
  ├─ user_id, device_id
  └─ access_level (view/control/admin)

firmware_updates (OTA)
  ├─ version, device_model
  ├─ download_url, md5_checksum
  └─ mandatory, release_notes

audit_log (security)
  ├─ user_id, action, resource
  └─ success, error_message

annotations (timeline notes)
  ├─ user_id, device_id
  ├─ annotation_time, text
  └─ annotation_type (manual/automatic)
```

**Row Level Security (RLS):**
- ✅ Admin/employee: full access to all devices
- ✅ Caretaker: access only to assigned devices via device_access
- ✅ Caretakee: access only to own linked devices
- ✅ Public insert allowed for sensor data (device uploads)
- ✅ Audit logging for all security-sensitive actions

**Realtime Subscriptions:**
- Live data updates via WebSocket
- Instant chart updates when new sensor data arrives
- No polling required

### Frontend Layer
**Web Dashboard (Vanilla JavaScript)**

**Pages:**
- `index.html` - Main dashboard with real-time charts and metrics
- `login.html` - Authentication (email/password, supports MFA/passkey)
- `admin.html` - Admin panel for user/device management
- `test_timeline.html` - Timeline testing and debugging

**Key Features:**
- Real-time data visualization (Chart.js)
- Three timeline views: 1-hour, 12-hour, 24-hour
- Time-based data aggregation (reduces rendering load by 83-97%)
- Automatic mode change annotations
- Device online/offline status indicators
- Role-based access control
- Responsive design (works on mobile/tablet/desktop)

**Deployment:**
- Hosted on Digital Ocean droplet: http://167.71.107.200
- Nginx web server
- Deployment script: `/deployment/deploy.sh`

---

## Completed Features

### ✅ Hardware & Firmware
- [x] ESP32-C6 + SEN0623 mmWave sensor integration
- [x] WiFi connectivity with auto-reconnect
- [x] Direct Supabase upload via ESPSupabase library
- [x] Dual collection modes (Quick: minimal, Medium: full sensors)
- [x] Remote configuration via cloud (60s sync interval)
- [x] Smart keep-alive optimization (97% bandwidth reduction when idle)
- [x] Fall detection monitoring (30s checks even when no presence)
- [x] OTA firmware update infrastructure
- [x] Device timestamp tracking
- [x] Human presence detection (eHumanPresence mapping)
- [x] Automatic retry logic for failed uploads

### ✅ Backend & Database
- [x] Supabase project setup with PostgreSQL
- [x] Complete database schema with indexes
- [x] Row Level Security policies for all roles
- [x] Authentication system (email/password)
- [x] User profile management with roles
- [x] Device access control system
- [x] Automatic profile creation trigger
- [x] Audit logging for security events
- [x] Firmware updates table for OTA
- [x] Annotations table for timeline notes
- [x] Realtime subscriptions enabled

### ✅ Frontend & Dashboard
- [x] Real-time data visualization dashboard
- [x] Authentication guard (redirects to login if not authenticated)
- [x] Role-based UI elements (show admin button only to admin/employee)
- [x] Three timeline views (1-hour, 12-hour, 24-hour)
- [x] Time-based data aggregation for performance
- [x] Query ordering fix (get recent data first, not old data)
- [x] Device timestamp usage for accurate time series
- [x] Automatic mode change annotations
- [x] Device online/offline status indicator
- [x] Metrics hide when device offline
- [x] Manual annotation capability
- [x] Admin panel for user/device/audit management
- [x] Login/signup UI with proper error handling

### ✅ Deployment & DevOps
- [x] Digital Ocean droplet setup
- [x] Nginx web server configuration
- [x] Deployment script with proper paths
- [x] Database migration scripts
- [x] Setup documentation (README.md, QUICKSTART.md)

---

## Current Capabilities

### What Works Right Now

**Device Monitoring:**
- ESP32-C6 device collects sensor data every 20 seconds
- Uploads to Supabase with automatic retry on failure
- Switches between "quick" and "medium" modes based on cloud config
- Sends keep-alive every 30s when no presence (bandwidth optimization)
- Full sensor data when presence/movement detected
- Fall detection checked every 30s for safety

**Real-Time Dashboard:**
- Live charts update automatically via Supabase Realtime
- 1-hour timeline shows last 60 minutes with full detail
- 12-hour timeline shows last 12 hours with 5-minute aggregation
- 24-hour timeline shows last 24 hours with 10-minute aggregation
- Aggregation reduces chart rendering from 1000+ points to ~144 points
- Device status shown as "Online" or "Offline (X seconds ago)"
- Metrics auto-hide when device offline for clean UI

**Authentication & Security:**
- Users can sign up and log in via email/password
- Session persistence across browser refreshes
- Automatic redirect to login if not authenticated
- Role-based access control ready (RLS policies in place)
- Audit logging for login/logout events

**Admin Panel:**
- Admin and employee users can access admin panel
- User management: view, create, edit, deactivate users
- Device assignment: grant/revoke access to specific devices
- Audit log viewing with filtering capabilities

**Over-The-Air Updates:**
- Firmware update infrastructure ready
- Device checks for updates every 1 hour (configurable)
- Update binary hosted in Supabase storage
- Automatic download, flash, and reboot on new version

### Data Being Collected

**Core Metrics (Quick Mode - Always):**
- Human presence (0=absent, 1=present)
- Body movement intensity (0-100)
- Motion detection range
- Distance to person (cm)
- Fall state monitoring

**Extended Metrics (Medium Mode - When Presence Detected):**
- Heart rate (BPM)
- Respiration rate (breaths/min)
- Sleep state and quality
- In bed detection
- Sleep duration (light/deep/total)
- Apnea events
- Abnormal struggle detection
- Time out of bed

---

## Recent Major Updates

### February 10, 2026 - Performance & Reliability Sprint

**1. Timeline Data Loss Fix (CRITICAL)**
- **Problem:** 12-hour and 24-hour timelines showed blank/missing data despite successful collection
- **Root Cause:** Queries ordered ascending, hitting 1000 limit, only returning oldest data
- **Solution:** Changed to descending order, increased limits (5k/10k/20k), reverse array
- **Impact:** Historical data now displays correctly across all timeframes

**2. Data Aggregation for Performance**
- **Problem:** Rendering 1000+ data points caused browser lag
- **Solution:** Time-based bucketing (5-min for 12h, 10-min for 24h)
- **Aggregation Logic:**
  - MAX for existence/motion (don't miss any activity)
  - AVERAGE for body_movement (smooth representation)
- **Impact:** 83-97% reduction in chart points, instant rendering

**3. Deployment Path Correction**
- **Problem:** Code updates not reaching production server
- **Root Cause:** deploy.sh used wrong relative path
- **Solution:** Fixed path from `dashboard/*` to `../web/dashboard/*`
- **Impact:** Deployments now work correctly

**4. Device Timestamp Migration**
- **Problem:** Server-side `created_at` didn't reflect when data was actually recorded
- **Solution:** Use `device_timestamp` from ESP32-C6 for all time series queries
- **Impact:** Accurate time representation even with upload delays

**5. Keep-Alive Optimization**
- **Problem:** Excessive bandwidth usage when room empty
- **Solution:** Send minimal "awake" message every 30s when no presence, full data when presence
- **Impact:** 97% bandwidth reduction during idle periods
- **Safety:** Still checks fall detection every 30s even when no presence

### February 8-9, 2026 - Admin Panel & Authentication

**6. Admin Panel Implementation**
- User management interface (view, create, edit, deactivate)
- Device access assignment UI
- Audit log viewing with filters
- Tab-based interface matching dashboard design

**7. Authentication System**
- Email/password login and signup
- Session management with auto-redirect
- Role-based access control (admin/employee/caretaker/caretakee)
- RLS policies for data isolation

### February 1-3, 2026 - Dual Modes & Annotations

**8. Data Collection Modes**
- "Quick" mode: minimal sensors, maximum battery
- "Medium" mode: full sensor suite when presence detected
- Remote configuration from cloud (60s sync)

**9. Timeline Annotations**
- Manual annotation capability
- Automatic mode change annotations
- Display on all timeline charts

### January 2026 - Initial Development

**10. Core System Setup**
- ESP32-C6 firmware with mmWave integration
- Supabase database and authentication
- Real-time dashboard with Chart.js
- Digital Ocean deployment

---

## Known Issues & Limitations

### Active Issues

**🔴 High Priority**
1. **Browser Cache Issue**
   - Users need hard refresh (Ctrl+Shift+R / Cmd+Shift+R) to see code updates
   - Affects: Newly deployed JavaScript changes
   - Workaround: Open incognito/private window or hard refresh
   - Solution: Add cache-busting query parameters to JS imports

**🟡 Medium Priority**
2. **Admin User Creation Limitation**
   - Creating users via admin panel requires service role key
   - Current: Must sign up via login page, then admin changes role via SQL
   - Affects: Admin panel user creation feature
   - Solution: Create backend endpoint with service role access

3. **No Email Confirmation Flow**
   - Email confirmation disabled for testing
   - Users can sign up with any email (not verified)
   - Affects: Production security
   - Solution: Enable email confirmation, configure templates

4. **Single Device Support**
   - Dashboard currently hardcoded to one device
   - Affects: Multi-device households
   - Solution: Add device selector UI

5. **No Historical Data Export**
   - Cannot download data as CSV/PDF
   - Affects: Reporting and record-keeping
   - Solution: Add export functionality to dashboard

**🟢 Low Priority**
6. **No Mobile App**
   - Only web interface available
   - Affects: Mobile-first users
   - Solution: Build React Native or Flutter app

7. **No Push Notifications**
   - Critical alerts only visible when dashboard open
   - Affects: Real-time emergency response
   - Solution: Implement web push notifications or SMS

8. **Limited Analytics**
   - Only raw charts, no trend analysis or insights
   - Affects: Long-term care planning
   - Solution: Add analytics dashboard with ML insights

---

## Testing Status

### ✅ Fully Tested
- ESP32-C6 WiFi connectivity and auto-reconnect
- Supabase data upload and retry logic
- Real-time chart updates via Realtime subscriptions
- Authentication login/signup flow
- Role-based access control (RLS policies)
- Timeline data aggregation
- Device online/offline status detection
- Automatic mode change annotations
- Deployment script

### 🧪 Partially Tested
- OTA firmware updates (infrastructure ready, not tested end-to-end)
- Multi-device scenarios (only tested with 1 device)
- Admin panel user creation (workaround tested, direct creation not tested)
- Fall detection (sensor tested, alert system not built)
- MFA/TOTP setup (backend ready, UI not built)
- Passkey authentication (backend ready, UI not built)

### ⏳ Not Yet Tested
- Scale testing (100+ devices)
- Long-term data retention (30+ days)
- Multiple concurrent users
- Network failure recovery scenarios
- Database backup and restore
- SSL/HTTPS deployment
- Cross-browser compatibility (only tested Chrome)
- Mobile responsive design on actual devices

---

## Deployment Information

### Production Environment

**Server:**
- Provider: Digital Ocean
- IP: 167.71.107.200
- OS: Ubuntu 22.04 LTS
- Web Server: Nginx
- User: deploy

**URLs:**
- Dashboard: http://167.71.107.200
- Login: http://167.71.107.200/login.html
- Admin: http://167.71.107.200/admin.html

**Deployment Process:**
```bash
cd /Users/johnreine/Dropbox/john/2025_work/moveOmeter/deployment
./deploy.sh deploy@167.71.107.200
```

This:
1. Uploads all dashboard files to `/tmp/moveometer-deploy/`
2. Copies to `/var/www/moveometer/`
3. Sets proper permissions (www-data:www-data)
4. Reloads Nginx

**Configuration Files:**
- Nginx config: `/etc/nginx/sites-available/moveometer`
- Dashboard files: `/var/www/moveometer/`
- Logs: `/var/log/nginx/access.log`, `/var/log/nginx/error.log`

### Development Environment

**Local Testing:**
```bash
cd /Users/johnreine/Dropbox/john/2025_work/moveOmeter/web/dashboard
python3 -m http.server 8000
open http://localhost:8000
```

**Arduino Development:**
- IDE: Arduino 2.x
- Board: ESP32C6 Dev Module
- Partition Scheme: Minimal SPIFFS (1.9MB APP with OTA/190KB SPIFFS)
- Upload Speed: 921600
- Serial Monitor: 115200 baud

**Required Libraries:**
- ESPSupabase (by jhagas)
- DFRobot_HumanDetection (by DFRobot)

### Database Management

**Supabase Project:**
- URL: (configured in `/web/dashboard/config.js`)
- Access: Supabase Dashboard → SQL Editor

**Key Tables:**
- `moveometers` - Device registry
- `mmwave_sensor_data` - Time series sensor data
- `user_profiles` - User accounts
- `device_access` - Permissions
- `firmware_updates` - OTA versions
- `audit_log` - Security events
- `annotations` - Timeline notes

**Migrations:**
Located in `/database/`:
- `setup_authentication.sql` - Auth system
- `create_annotations_only.sql` - Annotations feature
- `setup_data_access_rls.sql` - RLS policies
- `fix_*.sql` - Various bug fixes
- `run_all_migrations.sql` - Run all at once

---

## Documentation Index

### Getting Started
- `/deployment/QUICKSTART.md` - Quick deployment guide
- `/deployment/README.md` - Full deployment instructions
- `/pictureFrame/software/mmWave_Supabase_collector/README.md` - Firmware setup

### Authentication & Security
- `/web/dashboard/AUTH_SETUP.md` - Authentication configuration
- `/database/setup_authentication.sql` - Database setup for auth

### Features & Configuration
- `/DUAL_MODE_SETUP.md` - Quick/Medium collection modes
- `/ONLINE_CONFIG_SETUP.md` - Remote device configuration
- `/TIME_ACCURACY_SETUP.md` - Device timestamp implementation
- `/SAMPLING_RATE_CONFIG.md` - Data collection intervals
- `/SENSOR_QUERY_CONFIG.md` - mmWave sensor query types
- `/TIMELINE_ANNOTATION_OPTIONS.md` - Annotation implementation choices
- `/TIMELINE_ANNOTATIONS_GUIDE.md` - Using annotations feature

### OTA Updates
- `/database/OTA_QUICK_TEST.md` - OTA testing procedure
- `/database/OTA_SETUP_INSTRUCTIONS.md` - OTA infrastructure setup

### Hardware & Electrical
- `/hardware/moveOmeter_schematic.md` - Hardware design
- `/pictureFrame/electrical/part libraries/geophone/floor_pod_gait_firmware.md` - Floor sensor (future)

### Additional Documentation
- `/pictureFrame/software/CLAUDE.md` - AI assistant guidance (architecture overview)
- `/web/dashboard/README.md` - Dashboard features and usage

### Database Scripts
All in `/database/`:
- Setup scripts for each feature
- RLS policy fixes
- Trigger definitions
- Migration helpers

---

## Next Steps

See [ROADMAP.md](./ROADMAP.md) for the detailed development roadmap and prioritized task list.

**Immediate Next Actions:**
1. Test OTA firmware update end-to-end
2. Fix browser caching with query parameters
3. Add device selector to dashboard
4. Implement email confirmation flow
5. Test with multiple concurrent users

**For Full Roadmap:** See detailed planning in ROADMAP.md

---

## Support & Troubleshooting

### Common Issues

**Dashboard not loading:**
1. Check browser console (F12) for errors
2. Verify Supabase config in `/web/dashboard/config.js`
3. Check network tab for failed requests

**Device not uploading:**
1. Open Serial Monitor (115200 baud)
2. Look for "SUCCESS!" after upload attempts
3. Check WiFi connection status
4. Verify Supabase URL/key in firmware config

**Authentication errors:**
1. Check user exists in `user_profiles` table
2. Verify RLS policies allow access
3. Clear browser cookies and try again
4. Check audit_log for error details

**Deployment issues:**
1. Verify SSH access: `ssh deploy@167.71.107.200`
2. Check Nginx status: `sudo systemctl status nginx`
3. View logs: `sudo tail -f /var/log/nginx/error.log`
4. Verify files copied: `ls -la /var/www/moveometer/`

### Getting Help

1. Check relevant documentation (see index above)
2. Review browser console and server logs
3. Check Supabase logs (Dashboard → Logs)
4. Review audit_log table for security issues
5. Consult this document for known issues

---

**Document maintained by:** Development team
**Questions or updates?** Update this file with any significant changes to the project.
