# moveOmeter - IoT Elderly Monitoring System

**Version:** 1.0.0
**Status:** Active Development
**Last Updated:** February 10, 2026

---

## Quick Links

📊 **[Project Status & Progress](./PROJECT_STATUS.md)** - Complete overview of what's built and working
🗺️ **[Development Roadmap](./ROADMAP.md)** - Detailed plan for next 6-12 months
🤖 **[AI Agent Guide](./AI_AGENT_GUIDE.md)** - For AI assistants working on this project
🚀 **[Quick Start Guide](./deployment/QUICKSTART.md)** - Get up and running in 5 minutes
🔐 **[Authentication Setup](./web/dashboard/AUTH_SETUP.md)** - User management and security

---

## What is moveOmeter?

moveOmeter is a comprehensive IoT monitoring system designed to help families and caregivers look after elderly loved ones remotely. Using privacy-preserving mmWave radar technology, moveOmeter provides real-time insights into:

- **Activity Levels** - Daily movement and activity patterns
- **Sleep Quality** - Duration, quality, and sleep disturbances
- **Vital Signs** - Heart rate and respiration monitoring
- **Fall Detection** - Immediate alerts for falls or unusual events
- **Presence Detection** - Know when someone is home or has left

### Key Features

✅ **Privacy-First** - No cameras, no wearables, no user interaction required
✅ **Real-Time Monitoring** - Live data updates via web dashboard
✅ **Multi-Role Access** - Admins, employees, caretakers, and residents
✅ **Smart Alerts** - Notifications for falls, apnea, unusual patterns
✅ **Over-The-Air Updates** - Remote firmware updates without physical access
✅ **Secure & Scalable** - Role-based access control, designed for millions of users

---

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ESP32-C6 Device                      │
│         DFRobot SEN0623 mmWave Sensor                   │
│    ├─ Presence & Movement Detection                    │
│    ├─ Heart Rate & Respiration                         │
│    ├─ Sleep Quality Monitoring                         │
│    └─ Fall Detection                                   │
└────────────────┬────────────────────────────────────────┘
                 │ WiFi Upload (every 20s)
                 ▼
┌─────────────────────────────────────────────────────────┐
│              Supabase Backend (Cloud)                   │
│    ├─ PostgreSQL Database (sensor data)                │
│    ├─ Authentication (multi-role access)               │
│    ├─ Realtime Subscriptions (WebSocket)              │
│    ├─ Storage (firmware updates)                       │
│    └─ Row Level Security (data isolation)             │
└────────────────┬────────────────────────────────────────┘
                 │ HTTPS API
                 ▼
┌─────────────────────────────────────────────────────────┐
│              Web Dashboard (Browser)                    │
│    ├─ Real-time charts (1h, 12h, 24h views)           │
│    ├─ Device online/offline status                    │
│    ├─ Admin panel (user/device management)            │
│    ├─ Timeline annotations                            │
│    └─ Data export (CSV/PNG)                           │
└─────────────────────────────────────────────────────────┘
```

---

## Getting Started

### Prerequisites

**Hardware:**
- ESP32-C6 Feather development board
- DFRobot SEN0623 mmWave sensor
- USB-C cable for programming
- 5V power supply

**Software:**
- Arduino IDE 2.x
- Supabase account (free tier works)
- Web browser (Chrome/Firefox/Safari)

**Optional:**
- Digital Ocean droplet for deployment ($10/month)
- Domain name for SSL/HTTPS

### Installation

#### 1. Set Up Database

1. Create Supabase account at https://supabase.com
2. Create new project
3. Run database migrations:
   ```bash
   cd database/
   # Copy and paste run_all_migrations.sql into Supabase SQL Editor
   ```

#### 2. Configure Firmware

1. Install Arduino libraries:
   - ESPSupabase (by jhagas)
   - DFRobot_HumanDetection (by DFRobot)

2. Edit `pictureFrame/software/mmWave_Supabase_collector/config.h`:
   ```cpp
   #define WIFI_SSID "your_wifi"
   #define WIFI_PASSWORD "your_password"
   #define SUPABASE_URL "https://xxxxx.supabase.co"
   #define SUPABASE_ANON_KEY "your_key_here"
   #define DEVICE_ID "ESP32C6_001"
   ```

3. Select board: **ESP32C6 Dev Module**
4. Select partition: **Minimal SPIFFS (1.9MB APP with OTA/190KB SPIFFS)**
5. Upload to ESP32-C6

#### 3. Set Up Dashboard

**Option A: Local Testing**
```bash
cd web/dashboard/
python3 -m http.server 8000
open http://localhost:8000
```

**Option B: Deploy to Server**
```bash
cd deployment/
./deploy.sh deploy@your-server-ip
```

See [deployment/QUICKSTART.md](./deployment/QUICKSTART.md) for detailed instructions.

#### 4. Create First User

1. Open dashboard in browser
2. Click "Sign Up"
3. Create account
4. In Supabase Dashboard → Table Editor → user_profiles
5. Change your `role` to `'admin'`

Now you have full admin access!

---

## Documentation Index

### Core Documentation
| Document | Description |
|----------|-------------|
| **[PROJECT_STATUS.md](./PROJECT_STATUS.md)** | Complete project status, features, and capabilities |
| **[ROADMAP.md](./ROADMAP.md)** | Development roadmap with prioritized tasks |
| **[AI_AGENT_GUIDE.md](./AI_AGENT_GUIDE.md)** | Comprehensive guide for AI coding assistants |
| **[README.md](./README.md)** | This file - project overview and quick reference |

### Deployment & Setup
| Document | Path |
|----------|------|
| Quick Start Guide | [deployment/QUICKSTART.md](./deployment/QUICKSTART.md) |
| Full Deployment Guide | [deployment/README.md](./deployment/README.md) |
| Firmware Setup | [pictureFrame/software/mmWave_Supabase_collector/README.md](./pictureFrame/software/mmWave_Supabase_collector/README.md) |
| Dashboard Setup | [web/dashboard/README.md](./web/dashboard/README.md) |

### Authentication & Security
| Document | Path |
|----------|------|
| Authentication Setup | [web/dashboard/AUTH_SETUP.md](./web/dashboard/AUTH_SETUP.md) |
| RLS Policies | [database/setup_data_access_rls.sql](./database/setup_data_access_rls.sql) |
| Database Schema | [database/setup_authentication.sql](./database/setup_authentication.sql) |

### Features & Configuration
| Feature | Documentation |
|---------|---------------|
| Dual Collection Modes | [DUAL_MODE_SETUP.md](./DUAL_MODE_SETUP.md) |
| Remote Configuration | [ONLINE_CONFIG_SETUP.md](./ONLINE_CONFIG_SETUP.md) |
| Device Timestamps | [TIME_ACCURACY_SETUP.md](./TIME_ACCURACY_SETUP.md) |
| Data Collection Rates | [SAMPLING_RATE_CONFIG.md](./SAMPLING_RATE_CONFIG.md) |
| Sensor Queries | [SENSOR_QUERY_CONFIG.md](./SENSOR_QUERY_CONFIG.md) |
| Timeline Annotations | [TIMELINE_ANNOTATIONS_GUIDE.md](./TIMELINE_ANNOTATIONS_GUIDE.md) |
| OTA Updates | [database/OTA_QUICK_TEST.md](./database/OTA_QUICK_TEST.md) |

### Hardware
| Document | Path |
|----------|------|
| Hardware Schematic | [hardware/moveOmeter_schematic.md](./hardware/moveOmeter_schematic.md) |
| Floor Sensor (Future) | [pictureFrame/electrical/part libraries/geophone/floor_pod_gait_firmware.md](./pictureFrame/electrical/part libraries/geophone/floor_pod_gait_firmware.md) |

### Development
| Document | Path |
|----------|------|
| Architecture Guide | [pictureFrame/software/CLAUDE.md](./pictureFrame/software/CLAUDE.md) |
| Serial Passthrough | [pictureFrame/software/Arduino_mmWave_serialpassthrough/README.md](./pictureFrame/software/Arduino_mmWave_serialpassthrough/README.md) |

---

## Current Capabilities

### ✅ What's Working Now

**Device Monitoring:**
- ESP32-C6 collecting sensor data every 20 seconds
- Automatic upload to cloud with retry logic
- Dual modes: "quick" (minimal) and "medium" (full sensors)
- Smart keep-alive (30s when idle, full data when active)
- Fall detection monitoring every 30 seconds
- Remote configuration sync every 60 seconds
- OTA firmware update capability

**Real-Time Dashboard:**
- Live charts with automatic updates
- Three timeline views (1-hour, 12-hour, 24-hour)
- Data aggregation for performance (reduces load by 83-97%)
- Device online/offline status indicator
- Manual annotations on timeline
- Automatic mode change annotations
- Export data as CSV

**Authentication & Admin:**
- Email/password login and signup
- Role-based access (admin/employee/caretaker/caretakee)
- Row Level Security for data isolation
- Admin panel for user/device management
- Audit logging for security events

**Deployment:**
- Running on Digital Ocean at http://167.71.107.200
- One-command deployment script
- Nginx web server configured

### 🚧 In Testing
- OTA firmware updates (infrastructure ready, needs testing)
- Multi-device scenarios (only tested with one device)
- Fall detection alerts (sensor works, UI alerts not built)

### 📋 Planned Next
See [ROADMAP.md](./ROADMAP.md) for detailed plan:
- Multi-device selector in dashboard
- Email confirmation for signups
- Mobile-responsive design
- Progressive Web App (PWA)
- React Native mobile app
- Advanced analytics and insights

---

## Quick Reference

### Useful Commands

**Start local dashboard:**
```bash
cd web/dashboard && python3 -m http.server 8000
```

**Deploy to server:**
```bash
cd deployment && ./deploy.sh deploy@167.71.107.200
```

**Upload firmware:**
1. Open Arduino IDE
2. Select ESP32C6 Dev Module
3. Select partition: Minimal SPIFFS (1.9MB APP with OTA)
4. Upload sketch

**View device logs:**
```bash
# Arduino Serial Monitor at 115200 baud
# Look for "SUCCESS!" after uploads
```

**Check database:**
```sql
-- Recent sensor data
SELECT * FROM mmwave_sensor_data
ORDER BY created_at DESC LIMIT 10;

-- Device status
SELECT device_id, firmware_version, last_config_check
FROM moveometers;

-- User list
SELECT email, full_name, role, is_active
FROM user_profiles;
```

### Troubleshooting

**Device not uploading?**
1. Check Serial Monitor for errors
2. Verify WiFi connection
3. Check Supabase URL and key in config.h
4. Test with "ping 8.8.8.8" in Serial Monitor

**Dashboard not loading data?**
1. Open browser console (F12)
2. Check for network errors
3. Verify config.js has correct Supabase credentials
4. Test Supabase connection directly

**Authentication issues?**
1. Clear browser cookies
2. Check user exists in user_profiles table
3. Verify role is set correctly
4. Review audit_log for errors

**Deployment problems?**
```bash
# Check server
ssh deploy@167.71.107.200
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log

# Check files deployed
ls -la /var/www/moveometer/
```

---

## Project Structure

```
moveOmeter/
├── README.md                          # This file
├── PROJECT_STATUS.md                  # Complete status
├── ROADMAP.md                         # Development plan
│
├── pictureFrame/
│   └── software/
│       └── mmWave_Supabase_collector/ # ESP32-C6 firmware
│           ├── mmWave_Supabase_collector.ino
│           ├── config.h               # WiFi & Supabase config
│           └── README.md
│
├── web/
│   └── dashboard/                     # Web interface
│       ├── index.html                 # Main dashboard
│       ├── login.html                 # Login page
│       ├── admin.html                 # Admin panel
│       ├── dashboard.js               # Chart logic
│       ├── auth.js                    # Authentication
│       ├── auth-guard.js              # Auth protection
│       ├── config.js                  # Supabase config
│       └── README.md
│
├── database/                          # SQL migrations
│   ├── setup_authentication.sql       # Auth system
│   ├── setup_data_access_rls.sql      # RLS policies
│   ├── create_annotations_only.sql    # Annotations
│   ├── run_all_migrations.sql         # All-in-one
│   └── OTA_QUICK_TEST.md              # OTA testing
│
├── deployment/                        # Deployment tools
│   ├── deploy.sh                      # Deploy script
│   ├── README.md                      # Full guide
│   └── QUICKSTART.md                  # Quick guide
│
└── hardware/                          # Hardware docs
    └── moveOmeter_schematic.md
```

---

## Technology Stack

### Hardware
- **ESP32-C6 Feather** - Adafruit development board
- **DFRobot SEN0623** - C1001 mmWave human detection sensor
- **Communication:** WiFi 2.4GHz, UART (9600 baud for sensor)

### Firmware
- **Language:** C++ (Arduino)
- **Framework:** Arduino Core for ESP32
- **Libraries:** ESPSupabase, DFRobot_HumanDetection
- **Features:** OTA updates, WiFi auto-reconnect, retry logic

### Backend
- **Database:** Supabase (PostgreSQL)
- **Authentication:** Supabase Auth (email/password, supports MFA/passkey)
- **Storage:** Supabase Storage (firmware binaries)
- **Realtime:** Supabase Realtime (WebSocket subscriptions)
- **Security:** Row Level Security (RLS) policies

### Frontend
- **Framework:** Vanilla JavaScript (no framework)
- **Charts:** Chart.js
- **Styling:** Custom CSS with gradients
- **Real-time:** Supabase JavaScript SDK

### Deployment
- **Web Server:** Nginx
- **Hosting:** Digital Ocean Ubuntu 22.04 droplet
- **Domain:** TBD (currently IP only)
- **SSL:** Not yet configured (HTTP only)

### Future Stack
- **Mobile:** React Native (iOS + Android)
- **Analytics:** Custom ML models or cloud ML services
- **Notifications:** Firebase Cloud Messaging
- **Monitoring:** Sentry, LogRocket
- **Testing:** Jest, Vitest, Detox

---

## Team & Contributing

**Current Status:** Single developer, seeking contributors

**Roles Needed:**
- Frontend developers (React Native experience)
- ML/AI engineers (health analytics)
- DevOps engineers (scaling & reliability)
- UX designers (mobile app, dashboard improvements)
- Healthcare advisors (clinical validation)

**Contributing:**
1. Read [PROJECT_STATUS.md](./PROJECT_STATUS.md) and [ROADMAP.md](./ROADMAP.md)
2. Check Issues for open tasks
3. Fork repository, create branch
4. Submit pull request with detailed description

---

## License & Legal

**License:** TBD (currently proprietary)

**Privacy Policy:** TBD
**Terms of Service:** TBD

**Important Notes:**
- This system is for monitoring and assistance only
- Not a medical device - not FDA approved
- Not a substitute for professional medical care
- Emergency services should be called for serious incidents
- Data privacy and security are top priorities

---

## Contact & Support

**Documentation Issues:** Update this README or related docs

**Technical Support:**
- Check troubleshooting section above
- Review relevant documentation
- Check browser console and server logs
- Review Supabase logs

**Feature Requests:**
- See [ROADMAP.md](./ROADMAP.md) for planned features
- Submit detailed feature request with use case

---

## Version History

### v1.0.0 - February 10, 2026
**Core Features:**
- ESP32-C6 firmware with dual collection modes
- Real-time web dashboard with 3 timeline views
- Authentication system with 4 user roles
- Admin panel for user/device management
- OTA firmware update capability
- Timeline annotations
- Data aggregation for performance

**Recent Fixes:**
- Timeline query ordering (get recent data, not old)
- Device timestamp usage for accurate time series
- Deployment script path correction
- Human presence detection mapping
- Smart keep-alive optimization

**Documentation:**
- Complete project status documentation
- Detailed 6-12 month roadmap
- Comprehensive setup guides
- Feature-specific documentation

---

## Acknowledgments

**Hardware:**
- Adafruit - ESP32-C6 Feather board
- DFRobot - SEN0623 mmWave sensor

**Software:**
- Supabase - Backend-as-a-Service
- Chart.js - Data visualization
- Arduino community - ESP32 support

**Inspiration:**
- Built with care for families supporting elderly loved ones
- Privacy-first approach to health monitoring
- Open to collaboration and improvement

---

**Ready to get started?** See [deployment/QUICKSTART.md](./deployment/QUICKSTART.md)

**Questions about the project?** Read [PROJECT_STATUS.md](./PROJECT_STATUS.md)

**Want to contribute?** Check [ROADMAP.md](./ROADMAP.md) for priorities
