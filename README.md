# moveOmeter

### Privacy-Preserving IoT Monitoring for Elderly Care

> Help your loved ones live independently longer with non-invasive, radar-based health monitoring.

[![Status](https://img.shields.io/badge/status-active%20development-blue)](https://github.com/johnreine/moveOmeter)
[![License](https://img.shields.io/badge/license-proprietary-red)](./LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-green)](./PROJECT_STATUS.md)
[![Platform](https://img.shields.io/badge/platform-ESP32--C6-orange)](https://www.adafruit.com/product/5933)

---

## 🎯 The Problem

Families want to care for aging loved ones while respecting their independence and privacy. Traditional monitoring requires cameras (invasive) or wearables (forgotten/rejected).

## 💡 Our Solution

**moveOmeter** uses mmWave radar technology to monitor health and activity patterns without cameras or wearables. The system tracks:

- 🚶 **Activity & Movement** - Daily patterns and mobility changes
- 😴 **Sleep Quality** - Duration, disturbances, and sleep score
- ❤️ **Vital Signs** - Heart rate and respiration (contactless)
- 🚨 **Fall Detection** - Instant alerts for falls or emergencies
- 🏠 **Presence Detection** - Know when they're home or away

**No cameras. No wearables. No user interaction required.**

---

## ✨ Key Features

### Privacy-First Design
- ✅ Radar technology (sees motion, not images)
- ✅ No video, no photos, no recording
- ✅ HIPAA-compliant architecture ready

### Real-Time Monitoring
- ✅ Live web dashboard with charts
- ✅ Mobile-responsive interface
- ✅ Instant WebSocket updates
- ✅ Historical trend analysis

### Smart & Adaptive
- ✅ Learns individual patterns
- ✅ Detects anomalies automatically
- ✅ Over-the-air firmware updates
- ✅ Remote configuration

### Secure & Scalable
- ✅ Role-based access control (admin/employee/caretaker/resident)
- ✅ End-to-end encryption
- ✅ Audit logging
- ✅ Designed to scale to millions of users

---

## 📸 Screenshots

### Real-Time Dashboard
> 🚧 *Screenshot coming soon - see [deployment guide](./deployment/QUICKSTART.md) to run locally*

**Features visible in dashboard:**
- Live timeline charts (1-hour, 12-hour, 24-hour views)
- Activity metrics (movement, presence, sleep quality)
- Device status (online/offline)
- Manual annotations
- Alert notifications

### Admin Panel
> 🚧 *Screenshot coming soon*

**Manage users and devices:**
- User management (create, edit, roles)
- Device assignment
- Access control
- Audit logs

---

## 🚀 Quick Start

### Prerequisites
- ESP32-C6 Feather development board
- DFRobot SEN0623 mmWave sensor
- Supabase account (free tier works)
- Arduino IDE 2.x

### 5-Minute Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/johnreine/moveOmeter.git
   cd moveOmeter
   ```

2. **Set up database**
   - Create Supabase project at https://supabase.com
   - Run migrations: `database/run_all_migrations.sql`

3. **Configure firmware**
   ```bash
   # Edit pictureFrame/software/mmWave_Supabase_collector/config.h
   # Add your WiFi credentials and Supabase URL/key
   ```

4. **Upload to ESP32-C6**
   - Open Arduino IDE
   - Select board: ESP32C6 Dev Module
   - Upload sketch

5. **Start dashboard**
   ```bash
   cd web/dashboard
   python3 -m http.server 8000
   open http://localhost:8000
   ```

**Full setup guide:** [deployment/QUICKSTART.md](./deployment/QUICKSTART.md)

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────┐
│  ESP32-C6 + mmWave Sensor (DFRobot SEN0623)         │
│  • Collects 40+ health metrics every 20 seconds     │
│  • WiFi upload to cloud                             │
│  • OTA firmware updates                             │
└─────────────────┬────────────────────────────────────┘
                  │ HTTPS Upload
                  ▼
┌──────────────────────────────────────────────────────┐
│  Supabase Backend (PostgreSQL + Auth + Realtime)    │
│  • Time-series sensor data storage                  │
│  • Role-based access control (RLS)                  │
│  • Real-time WebSocket subscriptions                │
│  • OTA firmware distribution                        │
└─────────────────┬────────────────────────────────────┘
                  │ WebSocket + REST API
                  ▼
┌──────────────────────────────────────────────────────┐
│  Web Dashboard (Vanilla JS + Chart.js)              │
│  • Live charts and metrics                          │
│  • User authentication                              │
│  • Admin panel                                      │
│  • Mobile responsive                                │
└──────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

### Hardware
![ESP32](https://img.shields.io/badge/ESP32--C6-000000?style=flat&logo=espressif&logoColor=white)
![Sensor](https://img.shields.io/badge/mmWave-SEN0623-blue)

### Backend
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=flat&logo=supabase&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=flat&logo=postgresql&logoColor=white)

### Frontend
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=flat&logo=javascript&logoColor=black)
![Chart.js](https://img.shields.io/badge/Chart.js-FF6384?style=flat&logo=chartdotjs&logoColor=white)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=flat&logo=html5&logoColor=white)

### Firmware
![Arduino](https://img.shields.io/badge/Arduino-00979D?style=flat&logo=arduino&logoColor=white)
![C++](https://img.shields.io/badge/C++-00599C?style=flat&logo=cplusplus&logoColor=white)

### Deployment
![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)
![Digital Ocean](https://img.shields.io/badge/Digital_Ocean-0080FF?style=flat&logo=digitalocean&logoColor=white)

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[Project Status](./PROJECT_STATUS.md)** | Complete overview of features and progress |
| **[Development Roadmap](./ROADMAP.md)** | 6-12 month development plan |
| **[AI Agent Guide](./AI_AGENT_GUIDE.md)** | For AI coding assistants (Claude, GPT, etc.) |
| **[Quick Start](./deployment/QUICKSTART.md)** | Get running in 5 minutes |
| **[Full Deployment Guide](./deployment/README.md)** | Production deployment instructions |
| **[Authentication Setup](./web/dashboard/AUTH_SETUP.md)** | User management and security |
| **[Firmware README](./pictureFrame/software/mmWave_Supabase_collector/README.md)** | ESP32-C6 firmware details |
| **[OTA Testing Guide](./database/OTA_QUICK_TEST.md)** | Test firmware updates |

---

## 🗺️ Roadmap

### ✅ Current (v1.0) - Complete
- ESP32-C6 firmware with dual collection modes
- Real-time web dashboard with charts
- Authentication system (4 user roles)
- Admin panel for user/device management
- OTA firmware update infrastructure
- Timeline annotations
- Data aggregation for performance

### 🚧 Next Month (v1.1)
- [ ] Multi-device support in dashboard
- [ ] Progressive Web App (PWA)
- [ ] Email notifications
- [ ] Activity summary reports
- [ ] Mobile-responsive design improvements

### 🔮 Next Quarter (v1.5)
- [ ] React Native mobile app (iOS + Android)
- [ ] Predictive health alerts (ML-based)
- [ ] Medication reminder integration
- [ ] Voice integration (Alexa/Google Home)
- [ ] Family sharing features

### 🎯 Long-Term Vision
- AI-powered gait analysis and fall risk prediction
- Behavior pattern recognition
- White-label solution for senior living facilities
- Integration ecosystem (Apple Health, etc.)

**Full roadmap:** [ROADMAP.md](./ROADMAP.md)

---

## 🤝 Contributing

We welcome contributions! This project is currently in active development.

### How to Contribute

1. **Read the docs**
   - [Project Status](./PROJECT_STATUS.md) - Current state
   - [Roadmap](./ROADMAP.md) - Planned features
   - [AI Agent Guide](./AI_AGENT_GUIDE.md) - Technical details

2. **Find an issue**
   - Check [Issues](https://github.com/johnreine/moveOmeter/issues) for open tasks
   - Look for `good first issue` or `help wanted` labels

3. **Fork and create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Make your changes**
   - Follow existing code style
   - Add tests if applicable
   - Update documentation

5. **Submit a pull request**
   - Clear description of changes
   - Reference related issues
   - Screenshots for UI changes

### Development Setup

```bash
# Clone repository
git clone https://github.com/johnreine/moveOmeter.git
cd moveOmeter

# Install Arduino libraries
# - ESPSupabase (by jhagas)
# - DFRobot_HumanDetection (by DFRobot)

# Set up Supabase
# 1. Create account at https://supabase.com
# 2. Run database/run_all_migrations.sql

# Start local dashboard
cd web/dashboard
python3 -m http.server 8000
```

### Code Style

- **JavaScript:** ES6+, async/await, template literals
- **C++:** Arduino style, comments for complex logic
- **SQL:** Uppercase keywords, clear comments
- **Documentation:** Markdown with clear headings

---

## 🌟 Use Cases

### For Families
- Monitor aging parents remotely
- Peace of mind while at work
- Early detection of health changes
- Respect privacy (no cameras)

### For Caregivers
- Track multiple clients
- Shift handoff notes
- Medication reminders
- Fall alerts

### For Senior Living Facilities
- Monitor all residents
- Staff coordination
- Compliance reporting
- Emergency response

### For Healthcare Providers
- Remote patient monitoring
- Post-discharge tracking
- Chronic condition management
- Reduce hospital readmissions

---

## 📊 Project Stats

- **40 files** of comprehensive documentation
- **16,000+ lines** of code and docs
- **40+ sensor metrics** collected
- **4 user roles** with granular permissions
- **3 timeline views** (1h, 12h, 24h)
- **97% bandwidth reduction** with smart keep-alive
- **OTA updates** for remote firmware deployment

---

## 🔐 Security & Privacy

### Privacy Protections
- ✅ No cameras or video recording
- ✅ Radar technology (motion only, not images)
- ✅ Data encrypted in transit (HTTPS)
- ✅ Data encrypted at rest (Supabase)
- ✅ Row Level Security (RLS) for data isolation

### Compliance Ready
- 🔜 HIPAA compliance architecture
- 🔜 GDPR data handling
- 🔜 SOC 2 Type II準備中

### Security Features
- Multi-factor authentication (MFA) support
- Passkey/WebAuthn ready
- Audit logging for all actions
- Role-based access control
- Automatic session management

---

## 🛡️ Testing

### Current Test Coverage
- ✅ End-to-end firmware testing
- ✅ Real-time data pipeline
- ✅ Authentication flows
- ✅ Role-based access control
- 🚧 Cross-browser compatibility
- 🚧 Scale testing (100-1000 devices)

### Tested Environments
- **Firmware:** ESP32-C6 Feather
- **Browsers:** Chrome, Firefox, Safari (desktop)
- **Database:** Supabase (PostgreSQL 15)
- **Deployment:** Ubuntu 22.04 + Nginx

---

## 💰 Cost to Run

### Development (Current)
- **Supabase:** Free tier (good for 10 devices)
- **Digital Ocean:** $10-20/month
- **Total:** ~$10-20/month

### Small Deployment (100 devices)
- **Supabase:** $25/month (Pro tier)
- **Digital Ocean:** $20/month
- **Total:** ~$45/month

### Medium Scale (1,000 devices)
- **Supabase:** $599/month (Team tier)
- **Digital Ocean/AWS:** $100-200/month
- **Total:** ~$700-800/month

**Note:** Costs scale linearly. See [ROADMAP.md](./ROADMAP.md) for scaling details.

---

## 📄 License

**Proprietary** - All rights reserved.

This project is currently not open source. Contact for licensing inquiries.

---

## 📞 Contact & Support

### Questions or Issues?
1. Check [Project Status](./PROJECT_STATUS.md) and [Roadmap](./ROADMAP.md)
2. Review [documentation](./deployment/README.md)
3. Open an [Issue](https://github.com/johnreine/moveOmeter/issues)

### Business Inquiries
- **Email:** contact@moveometer.com (TBD)
- **Website:** https://moveometer.com (TBD)

### For Contributors
- Join discussions in [Issues](https://github.com/johnreine/moveOmeter/issues)
- Submit [Pull Requests](https://github.com/johnreine/moveOmeter/pulls)
- See [AI Agent Guide](./AI_AGENT_GUIDE.md) for technical details

---

## 🙏 Acknowledgments

### Hardware
- **Adafruit** - ESP32-C6 Feather development board
- **DFRobot** - SEN0623 mmWave sensor

### Software & Services
- **Supabase** - Backend-as-a-Service platform
- **Chart.js** - Beautiful data visualization
- **Arduino** - ESP32 development framework

### Inspiration
Built with care for families supporting elderly loved ones. Inspired by the need for privacy-preserving health monitoring that maintains dignity and independence.

---

## ⭐ Star History

If you find this project useful, consider giving it a star! ⭐

---

## 📈 Project Activity

![GitHub last commit](https://img.shields.io/github/last-commit/johnreine/moveOmeter)
![GitHub commit activity](https://img.shields.io/github/commit-activity/m/johnreine/moveOmeter)

---

<div align="center">

**Made with ❤️ for better elderly care**

[Documentation](./PROJECT_STATUS.md) • [Roadmap](./ROADMAP.md) • [Contributing](#contributing) • [License](#license)

</div>
