# moveOmeter Development Roadmap

**Last Updated:** February 10, 2026
**Planning Horizon:** February 2026 - August 2026

> **🤖 For AI Assistants:** See [AI_AGENT_GUIDE.md](./AI_AGENT_GUIDE.md) for technical implementation details and best practices when working on roadmap items.

---

## Table of Contents

1. [Current Sprint (Next 2 Weeks)](#current-sprint-next-2-weeks)
2. [Short-Term Goals (Next Month)](#short-term-goals-next-month)
3. [Medium-Term Objectives (Next Quarter)](#medium-term-objectives-next-quarter)
4. [Long-Term Vision (Next 6-12 Months)](#long-term-vision-next-6-12-months)
5. [Technical Debt](#technical-debt)
6. [Feature Wishlist](#feature-wishlist)
7. [Scaling Roadmap](#scaling-roadmap)

---

## Current Sprint (Next 2 Weeks)
**Timeline:** February 10-23, 2026
**Focus:** Testing, Bug Fixes, Essential Features

### 🔴 Critical Priority

#### 1. OTA Firmware Update Testing
**Status:** Infrastructure complete, needs end-to-end testing
**Effort:** 2-4 hours
**Prerequisites:** ESP32-C6 device available, Supabase storage configured

**Tasks:**
- [ ] Follow `/database/OTA_QUICK_TEST.md` procedure
- [ ] Create firmware v1.0.1 with visible change
- [ ] Export binary and upload to Supabase storage
- [ ] Create firmware_updates record in database
- [ ] Monitor Serial Monitor for OTA process
- [ ] Verify device reboots with new firmware
- [ ] Test rollback on bad firmware
- [ ] Document any issues encountered

**Success Criteria:**
- Device successfully downloads and flashes new firmware
- Reboots automatically into new version
- Database shows `ota_status: "success"`
- No manual intervention required

**Risks:**
- Partition scheme incorrect → device won't boot
- Download URL inaccessible → download fails
- MD5 mismatch → flash aborted
- Network interruption → partial flash (auto-rollback should handle)

---

#### 2. Browser Cache-Busting Implementation
**Status:** Active issue preventing users from seeing updates
**Effort:** 1 hour
**Priority:** High (affects all deployments)

**Problem:**
Users must hard refresh (Ctrl+Shift+R) to see JavaScript changes after deployment.

**Solution Options:**

**Option A: Query Parameter Versioning (Recommended)**
```html
<!-- In index.html, admin.html, login.html -->
<script src="config.js?v=1.0.1"></script>
<script src="auth-guard.js?v=1.0.1"></script>
<script src="dashboard.js?v=1.0.1"></script>
```

**Option B: Timestamp-Based (Dynamic)**
```html
<script>
  const version = Date.now();
</script>
<script src="config.js?v=' + version + '"></script>
```

**Option C: Hash-Based (Build Process)**
```bash
# Generate hash of file contents
md5 dashboard.js → abc123def456
# Rename: dashboard.abc123.js
```

**Tasks:**
- [ ] Decide on cache-busting strategy (recommend Option A)
- [ ] Update all HTML files with versioned imports
- [ ] Create VERSION file or constant
- [ ] Update deployment script to bump version
- [ ] Test with existing deployment
- [ ] Document versioning process

**Success Criteria:**
- Users see updates without hard refresh
- No manual cache clearing required
- Version increment automated in deploy script

---

#### 3. Fix Admin Panel User Creation
**Status:** Workaround exists, needs proper solution
**Effort:** 3-5 hours
**Current Workaround:** Users sign up via login page, admin manually changes role

**Problem:**
Admin panel tries to use `auth.admin.createUser()` which requires service role key (not available client-side).

**Solution Options:**

**Option A: Supabase Edge Function (Recommended)**
```typescript
// /database/edge-functions/create-user.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Verify caller is admin
  const authHeader = req.headers.get('Authorization')
  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL'),
    Deno.env.get('SUPABASE_ANON_KEY')
  )

  const { data: { user } } = await supabaseClient.auth.getUser(authHeader)
  // Check user.role === 'admin'

  // Create user with service role
  const adminClient = createClient(
    Deno.env.get('SUPABASE_URL'),
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  )

  const { email, password, full_name, role } = await req.json()

  const { data, error } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name }
  })

  // Update role in user_profiles
  await adminClient
    .from('user_profiles')
    .update({ role })
    .eq('id', data.user.id)

  return new Response(JSON.stringify({ success: true, user: data.user }))
})
```

**Option B: Backend API Server**
- Create Node.js/Python server
- Handle admin operations
- Deploy alongside Nginx

**Option C: Keep Workaround**
- Document the two-step process
- Accept limitation for now

**Recommendation:** Option A (Edge Function) - native to Supabase, serverless, secure

**Tasks:**
- [ ] Create Edge Function for user creation
- [ ] Deploy Edge Function to Supabase
- [ ] Update admin.js to call Edge Function instead of direct auth.admin
- [ ] Add error handling and validation
- [ ] Test user creation flow end-to-end
- [ ] Update AUTH_SETUP.md documentation

**Success Criteria:**
- Admin can create users directly from admin panel
- Email and password work immediately
- Role set correctly on creation
- No manual SQL intervention required

---

### 🟡 High Priority

#### 4. Multi-Device Support in Dashboard
**Status:** Dashboard hardcoded to single device
**Effort:** 4-6 hours

**Current Limitation:**
Dashboard can only display one device at a time (configured in config.js).

**Requirements:**
- Show dropdown to select device
- Remember last selected device (localStorage)
- Filter all charts/metrics by selected device
- Show device info (location, status, last update)

**Tasks:**
- [ ] Add device selector dropdown to dashboard header
- [ ] Fetch available devices based on user role and permissions
  - Admin/Employee: All devices
  - Caretaker: Devices in device_access table
  - Caretakee: Devices in caretakee_devices table
- [ ] Update all data queries to filter by selected device
- [ ] Store selected device in localStorage
- [ ] Add device info panel (location, firmware version, last seen)
- [ ] Handle device offline scenario (show last known data)
- [ ] Test with multiple devices

**Success Criteria:**
- User can switch between devices
- Selection persists across page refreshes
- Data correctly filtered by device
- No cross-device data leakage

**UI Mockup:**
```
┌────────────────────────────────────────────┐
│ moveOmeter Dashboard                       │
│                                            │
│ Device: [▼ Bedroom 1 (ESP32C6_001)    ]   │
│         [ ] Living Room (ESP32C6_002)      │
│         [ ] Kitchen (ESP32C6_003)          │
│                                            │
│ Status: 🟢 Online (updated 5 sec ago)     │
│ Location: Bedroom 1                        │
│ Firmware: v1.0.0                           │
└────────────────────────────────────────────┘
```

---

#### 5. Email Confirmation Flow
**Status:** Currently disabled for testing
**Effort:** 2 hours
**Impact:** Production security requirement

**Current State:**
- Email confirmation disabled in Supabase settings
- Any email can sign up without verification
- Acceptable for testing, not for production

**Tasks:**
- [ ] Enable email confirmation in Supabase
  - Go to Authentication → Settings
  - Enable "Confirm email"
- [ ] Customize email templates
  - Branding with moveOmeter logo/colors
  - Clear call-to-action
  - Instructions for new users
- [ ] Add "Resend confirmation" button to login page
- [ ] Add pending verification state to user_profiles
- [ ] Test signup → email → confirmation → login flow
- [ ] Document for users

**Success Criteria:**
- New users receive confirmation email
- Cannot log in until email confirmed
- Resend button works if email not received
- Email templates match branding

---

### 🟢 Medium Priority

#### 6. Add Data Export Functionality
**Status:** Not implemented
**Effort:** 3-4 hours

**Requirements:**
- Export sensor data as CSV
- Export timeline chart as image (PNG)
- Export summary report as PDF
- Date range selection for exports

**Tasks:**
- [ ] Add "Export" button to dashboard
- [ ] Implement CSV export
  ```javascript
  function exportToCSV(data, filename) {
    const csv = data.map(row =>
      Object.values(row).join(',')
    ).join('\n')

    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    a.click()
  }
  ```
- [ ] Implement chart image export (Chart.js toBase64Image)
- [ ] Add date range picker for export
- [ ] Test with large datasets (10k+ rows)
- [ ] Add loading indicator during export

**Success Criteria:**
- CSV contains all sensor fields with headers
- Chart image is high resolution
- Export completes in <5 seconds for 7 days of data
- Filename includes device and date range

---

#### 7. Improve Fall Detection Alert System
**Status:** Sensor queries fall state, no alerting
**Effort:** 2-3 hours

**Current Implementation:**
- Device queries fall state every 30s
- Stores in `fall_state` field
- No alert mechanism in dashboard

**Tasks:**
- [ ] Add fall detection to `checkAlerts()` function in dashboard.js
- [ ] Create visual alert banner when fall detected
- [ ] Add sound notification (optional, user preference)
- [ ] Log fall events to audit_log
- [ ] Add "Mark as resolved" button for falls
- [ ] Show fall history in timeline
- [ ] Test fall detection with sensor

**Success Criteria:**
- Dashboard shows prominent alert when fall_state != 0
- Sound plays if enabled
- Alert persists until acknowledged
- Fall events logged for review

**UI Mockup:**
```
┌─────────────────────────────────────────────┐
│ 🚨 FALL DETECTED                            │
│ Bedroom 1 - 2:34 PM                         │
│ [Mark as False Positive] [Emergency Called] │
└─────────────────────────────────────────────┘
```

---

## Short-Term Goals (Next Month)
**Timeline:** February 24 - March 23, 2026
**Focus:** Mobile Support, Advanced Features, Testing

### Mobile Web Optimization

#### 8. Responsive Dashboard Design
**Effort:** 6-8 hours

**Current State:**
- Desktop-first design
- Works on mobile but not optimized
- Charts may be hard to read on small screens

**Tasks:**
- [ ] Add responsive breakpoints
  ```css
  @media (max-width: 768px) {
    /* Tablet styles */
  }
  @media (max-width: 480px) {
    /* Mobile styles */
  }
  ```
- [ ] Stack timeline charts vertically on mobile
- [ ] Make metric cards smaller and wrap
- [ ] Add hamburger menu for navigation
- [ ] Optimize chart touch interactions
- [ ] Test on actual mobile devices (iOS, Android)
- [ ] Test on tablets (iPad, Android)

**Success Criteria:**
- Dashboard usable on iPhone and Android phones
- No horizontal scrolling
- Charts readable and interactive
- All buttons easily tappable (min 44px)

---

#### 9. Progressive Web App (PWA)
**Effort:** 4-5 hours

**Benefits:**
- Add to home screen like native app
- Offline support with service worker
- Push notification capability (future)
- Faster load times with caching

**Tasks:**
- [ ] Create `manifest.json`
  ```json
  {
    "name": "moveOmeter Dashboard",
    "short_name": "moveOmeter",
    "icons": [
      {
        "src": "icons/icon-192.png",
        "sizes": "192x192",
        "type": "image/png"
      }
    ],
    "start_url": "/",
    "display": "standalone",
    "background_color": "#667eea",
    "theme_color": "#667eea"
  }
  ```
- [ ] Add service worker for caching
- [ ] Create app icons (192x192, 512x512)
- [ ] Add meta tags for iOS
- [ ] Test "Add to Home Screen" on iOS and Android
- [ ] Implement offline fallback page

**Success Criteria:**
- Can install on home screen
- Works offline (shows cached data)
- Passes Lighthouse PWA audit
- Icons display correctly

---

### Advanced Analytics

#### 10. Activity Summary Dashboard
**Effort:** 8-10 hours

**Feature Description:**
Daily/weekly/monthly summary of activity patterns, sleep quality, and health trends.

**Metrics to Calculate:**
- Average sleep duration per night (last 7/30 days)
- Sleep quality score trend
- Active hours per day
- Out-of-bed frequency at night
- Heart rate variability
- Respiration rate trends
- Apnea event frequency
- Fall risk score (based on movement patterns)

**UI Components:**
- Summary cards with key metrics
- Trend charts (weekly/monthly)
- Comparison to previous period
- Insights and recommendations

**Tasks:**
- [ ] Create analytics queries (aggregate by day/week/month)
- [ ] Design summary dashboard UI
- [ ] Implement trend calculations
- [ ] Add date range selector
- [ ] Create comparison view (this week vs last week)
- [ ] Add export summary report
- [ ] Test with historical data

**Success Criteria:**
- Summary loads in <2 seconds
- Trends are accurate and meaningful
- Insights actionable for caretakers
- Export includes all metrics

---

#### 11. Predictive Health Alerts
**Effort:** 12-15 hours
**Prerequisites:** Requires historical data (30+ days)

**Feature Description:**
Machine learning model to detect anomalies and predict health issues before they become critical.

**Anomalies to Detect:**
- Unusual sleep patterns (insomnia, oversleeping)
- Decreased activity levels (depression, illness)
- Increased fall risk (gait changes)
- Respiration irregularities (early pneumonia)
- Sudden behavior changes

**Implementation Approach:**

**Phase 1: Rule-Based Alerts (Simpler)**
```javascript
// Example rules
if (sleepDuration < 4 && nightsInARow > 3) {
  alert('Severe insomnia detected')
}

if (activityLevel < baseline * 0.5 && daysInARow > 7) {
  alert('Decreased activity - possible illness')
}

if (fallsPerDay > 1) {
  alert('Increased fall risk')
}
```

**Phase 2: ML-Based (Advanced)**
- Train model on historical data
- Detect deviations from personal baseline
- Use Supabase Edge Functions with TensorFlow.js

**Tasks:**
- [ ] Define alert rules (Phase 1)
- [ ] Implement baseline calculation (personal normal)
- [ ] Create alert dashboard
- [ ] Add alert notification system
- [ ] Test with real data
- [ ] Refine thresholds based on feedback
- [ ] (Future) Implement ML model

**Success Criteria:**
- Alerts triggered appropriately (not too sensitive)
- False positive rate <10%
- Actionable insights for caretakers
- Alert history logged

---

### Multi-User Testing & Polish

#### 12. Cross-Browser Compatibility Testing
**Effort:** 3-4 hours

**Browsers to Test:**
- Chrome (Windows, Mac, Linux)
- Firefox (Windows, Mac)
- Safari (Mac, iOS)
- Edge (Windows)
- Mobile Safari (iOS)
- Chrome Mobile (Android)

**Test Cases:**
- [ ] Login/signup flow
- [ ] Dashboard charts render correctly
- [ ] Real-time updates work
- [ ] Responsive design adapts
- [ ] Admin panel functions
- [ ] Export features work
- [ ] No console errors

**Tasks:**
- [ ] Create browser testing checklist
- [ ] Test on each browser
- [ ] Document browser-specific issues
- [ ] Fix critical issues (blocking functionality)
- [ ] Add browser detection for warnings if needed

**Success Criteria:**
- Works on all modern browsers (last 2 versions)
- No critical bugs in any browser
- Graceful degradation for older browsers

---

#### 13. Performance Optimization
**Effort:** 5-7 hours

**Current Performance:**
- Dashboard loads in ~2-3 seconds
- Charts update smoothly
- Data aggregation implemented

**Optimization Opportunities:**
- [ ] Lazy load Chart.js (only when needed)
- [ ] Implement virtual scrolling for large tables
- [ ] Optimize Supabase queries (add indexes)
- [ ] Reduce bundle size (minify JS/CSS)
- [ ] Enable gzip compression in Nginx
- [ ] Add CDN for static assets
- [ ] Implement query result caching

**Tasks:**
- [ ] Run Lighthouse performance audit
- [ ] Identify bottlenecks
- [ ] Implement optimizations
- [ ] Re-run audit, compare scores
- [ ] Document performance best practices

**Success Criteria:**
- Lighthouse Performance score >90
- First Contentful Paint <1.5s
- Time to Interactive <3.5s
- Dashboard usable on slow 3G

---

## Medium-Term Objectives (Next Quarter)
**Timeline:** April - June 2026
**Focus:** Native Mobile App, Advanced Features, Scale Testing

### Native Mobile Application

#### 14. React Native Mobile App (iOS + Android)
**Effort:** 40-60 hours
**Skills Required:** React Native, JavaScript, Mobile development

**Rationale:**
While PWA works on mobile, native app provides:
- Better performance
- Native notifications
- App store presence
- Better offline support
- Native UI components

**Architecture:**
```
React Native App
├── Authentication (Supabase Auth)
├── Dashboard Screen
├── Device Selector
├── Timeline Charts
├── Alerts & Notifications
├── Settings
└── Profile Management
```

**Tasks:**

**Phase 1: Setup & Authentication (10h)**
- [ ] Initialize React Native project
- [ ] Set up navigation (React Navigation)
- [ ] Integrate Supabase SDK
- [ ] Implement login/signup screens
- [ ] Add biometric authentication (Face ID, fingerprint)
- [ ] Test on iOS simulator and Android emulator

**Phase 2: Dashboard (15h)**
- [ ] Create dashboard screen
- [ ] Integrate Chart.js or Victory Native
- [ ] Implement real-time data updates
- [ ] Add device selector
- [ ] Build metric cards
- [ ] Test on real devices

**Phase 3: Advanced Features (10h)**
- [ ] Push notifications (Firebase Cloud Messaging)
- [ ] Local data caching (AsyncStorage)
- [ ] Background data refresh
- [ ] Export functionality
- [ ] Settings screen
- [ ] Profile management

**Phase 4: Testing & Deployment (10h)**
- [ ] Unit tests (Jest)
- [ ] E2E tests (Detox)
- [ ] Beta testing (TestFlight, Google Play Beta)
- [ ] App store submissions
- [ ] App store optimization (screenshots, descriptions)

**Phase 5: Polish (5h)**
- [ ] Splash screen and app icon
- [ ] Onboarding tutorial
- [ ] Error handling and retry logic
- [ ] Analytics integration (optional)
- [ ] Crash reporting (Sentry)

**Success Criteria:**
- App works identically to web dashboard
- Published to App Store and Google Play
- 4+ star rating
- <1% crash rate

**Resources Needed:**
- Apple Developer Account ($99/year)
- Google Play Developer Account ($25 one-time)
- Mac for iOS development
- Android device or emulator for testing

---

### Multi-Device & Multi-User Features

#### 15. Family Sharing & Caretaker Collaboration
**Effort:** 10-12 hours

**Feature Description:**
Allow multiple caretakers to monitor the same resident, with collaboration tools.

**Features:**
- Share device access with family members
- Activity feed (who checked in when)
- Shared notes and annotations
- Assign tasks (medication reminders, check-ins)
- Shift scheduling for professional caretakers

**Database Changes:**
```sql
CREATE TABLE shared_access (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id TEXT REFERENCES moveometers(device_id),
  owner_id UUID REFERENCES user_profiles(id),
  shared_with_id UUID REFERENCES user_profiles(id),
  access_level TEXT CHECK (access_level IN ('view', 'annotate', 'manage')),
  shared_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  notification_preferences JSONB
);

CREATE TABLE care_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id TEXT REFERENCES moveometers(device_id),
  created_by UUID REFERENCES user_profiles(id),
  assigned_to UUID REFERENCES user_profiles(id),
  task_type TEXT,
  description TEXT,
  due_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  notes TEXT
);
```

**Tasks:**
- [ ] Design sharing UI
- [ ] Implement invitation system
- [ ] Add shared notes feature
- [ ] Create task management UI
- [ ] Add notifications for task assignments
- [ ] Test with multiple caretakers

**Success Criteria:**
- Can invite caretakers via email
- All caretakers see shared notes
- Tasks can be assigned and marked complete
- Notifications sent for critical events

---

#### 16. Multi-Home Management
**Effort:** 6-8 hours

**Feature Description:**
Support for families with multiple homes or facilities managing many residents.

**Features:**
- Group devices by location (house/facility)
- Dashboard shows all locations
- Switch between homes easily
- Aggregate statistics across all homes
- Admin view for facility managers

**UI Mockup:**
```
┌─────────────────────────────────────────┐
│ Homes                                   │
├─────────────────────────────────────────┤
│ 🏠 Main House (3 devices)               │
│    • Bedroom 1 - John (🟢 Online)       │
│    • Bedroom 2 - Mary (🟢 Online)       │
│    • Living Room (🔴 Offline)           │
│                                         │
│ 🏠 Vacation Home (1 device)             │
│    • Guest Room (🟢 Online)             │
│                                         │
│ 🏥 Sunrise Care Facility (24 devices)   │
│    • View All Residents →               │
└─────────────────────────────────────────┘
```

**Tasks:**
- [ ] Add homes table to database
- [ ] Link devices to homes
- [ ] Create home management UI
- [ ] Add home switcher to dashboard
- [ ] Aggregate statistics by home
- [ ] Test with multiple homes

**Success Criteria:**
- Can create and manage multiple homes
- Devices assigned to homes
- Easy navigation between homes
- Facility view shows all residents at once

---

### Advanced Health Monitoring

#### 17. Medication Reminder Integration
**Effort:** 8-10 hours

**Feature Description:**
Track medication schedules and remind caretakers/residents when medication is due.

**Features:**
- Medication schedule management
- Push notifications for medication times
- Mark as taken/skipped
- Adherence tracking and reporting
- Integration with activity patterns (if resident didn't get up, send alert)

**Database Schema:**
```sql
CREATE TABLE medications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id TEXT REFERENCES moveometers(device_id),
  medication_name TEXT NOT NULL,
  dosage TEXT,
  schedule TEXT[], -- ['08:00', '14:00', '20:00']
  start_date DATE,
  end_date DATE,
  notes TEXT
);

CREATE TABLE medication_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  medication_id UUID REFERENCES medications(id),
  scheduled_time TIMESTAMPTZ,
  taken_at TIMESTAMPTZ,
  status TEXT CHECK (status IN ('taken', 'skipped', 'missed')),
  taken_by UUID REFERENCES user_profiles(id),
  notes TEXT
);
```

**Tasks:**
- [ ] Design medication management UI
- [ ] Implement notification system
- [ ] Add medication log tracking
- [ ] Create adherence report
- [ ] Add missed medication alerts
- [ ] Test notification delivery

**Success Criteria:**
- Notifications sent on time
- Can track medication adherence
- Reports show compliance over time
- Alerts sent for missed medications

---

#### 18. Voice Integration (Alexa/Google Home)
**Effort:** 15-20 hours
**Prerequisites:** Alexa Developer Account, Actions on Google account

**Feature Description:**
Voice commands to check on loved ones.

**Example Commands:**
- "Alexa, ask moveOmeter how's mom doing?"
  - Response: "Your mom is doing well. She slept 7 hours last night and has been active today."
- "Hey Google, ask moveOmeter when did dad wake up?"
  - Response: "Your dad woke up at 6:30 AM this morning."
- "Alexa, ask moveOmeter if grandma is okay"
  - Response: "Grandma is currently in bed. Her heart rate is normal at 72 BPM."

**Tasks:**

**Alexa Skill (10h)**
- [ ] Create Alexa skill in developer console
- [ ] Design voice interaction model
- [ ] Implement skill backend (Lambda or Edge Function)
- [ ] Authenticate user with Supabase
- [ ] Query sensor data based on voice request
- [ ] Generate natural language responses
- [ ] Test with Alexa device
- [ ] Submit for certification

**Google Action (10h)**
- [ ] Create Actions on Google project
- [ ] Design conversation flow
- [ ] Implement fulfillment webhook
- [ ] Integrate with Supabase
- [ ] Test with Google Home
- [ ] Submit for review

**Success Criteria:**
- Voice commands work reliably
- Responses are natural and helpful
- User authentication secure
- Privacy-preserving (no recording of sensitive data)

---

### Scale Testing & Optimization

#### 19. Load Testing (100-1000 Devices)
**Effort:** 5-7 hours

**Objective:**
Verify system can handle 100-1000 concurrent devices without performance degradation.

**Tools:**
- Supabase (should auto-scale)
- Locust or k6 for load testing
- Monitoring: Supabase logs, custom dashboard

**Test Scenarios:**
1. **Normal Load:** 100 devices uploading every 20 seconds
2. **Peak Load:** 1000 devices uploading simultaneously
3. **Sustained Load:** 500 devices for 24 hours
4. **Dashboard Load:** 100 concurrent users viewing dashboards
5. **Query Performance:** Complex queries on 1M+ rows

**Tasks:**
- [ ] Create synthetic device data generator
- [ ] Write load testing scripts
- [ ] Set up monitoring dashboards
- [ ] Run tests incrementally (10, 50, 100, 500, 1000 devices)
- [ ] Identify bottlenecks
- [ ] Optimize database queries (add indexes)
- [ ] Re-test after optimizations
- [ ] Document findings and recommendations

**Success Criteria:**
- All devices upload successfully
- <1% upload failure rate
- Dashboard loads in <3 seconds with 1000 devices
- Database queries return in <500ms
- No Supabase rate limiting

**Expected Bottlenecks:**
- Supabase free tier limits (may need paid plan)
- Database query performance (add indexes)
- Real-time subscription limits (100 concurrent connections)
- Network bandwidth for dashboard charts

---

#### 20. Data Retention & Archival Strategy
**Effort:** 6-8 hours

**Problem:**
Sensor data accumulates quickly. 1000 devices × 3 records/min × 60 min × 24 hours = 4.32M rows/day.

**Requirements:**
- Keep recent data (30 days) in hot storage (fast queries)
- Archive older data (30+ days) to cold storage
- Ability to restore archived data for analysis
- Minimize storage costs

**Architecture:**

**Hot Storage (Supabase):**
- Last 30 days of sensor data
- Fast queries for dashboards
- Real-time subscriptions

**Cold Storage (S3/B2/Object Storage):**
- Data older than 30 days
- Compressed and partitioned by device/date
- Queryable via serverless analytics (DuckDB, Athena)

**Tasks:**
- [ ] Create archival script (runs daily)
  ```sql
  -- Export data older than 30 days
  COPY (
    SELECT * FROM mmwave_sensor_data
    WHERE created_at < NOW() - INTERVAL '30 days'
  ) TO 's3://moveometer-archive/2026/02/data.parquet'

  -- Delete archived data from hot storage
  DELETE FROM mmwave_sensor_data
  WHERE created_at < NOW() - INTERVAL '30 days'
  ```
- [ ] Set up S3 bucket or Backblaze B2
- [ ] Implement data compression (Parquet format)
- [ ] Create restore procedure
- [ ] Test archival and restore
- [ ] Schedule daily archival job
- [ ] Document data retention policy

**Success Criteria:**
- Archival runs automatically daily
- Storage costs <$10/month for 1M rows
- Can restore archived data within 1 hour
- No data loss during archival

---

## Long-Term Vision (Next 6-12 Months)
**Timeline:** July 2026 - February 2027
**Focus:** AI/ML, Advanced Analytics, Business Growth

### AI & Machine Learning

#### 21. Gait Analysis & Fall Risk Prediction
**Effort:** 30-40 hours
**Prerequisites:** DFRobot SEN0610 floor sensor, ML expertise

**Objective:**
Use floor-mounted sensors to analyze walking patterns and predict fall risk.

**Data to Collect:**
- Step length and width
- Walking speed
- Gait symmetry
- Balance metrics
- Foot pressure distribution

**ML Model:**
- Train on data from 100+ seniors
- Classify fall risk (low/medium/high)
- Update model as more data collected
- Real-time inference on device or cloud

**Deliverables:**
- Gait analysis dashboard
- Fall risk score (0-100)
- Recommendations (physical therapy, walker, etc.)
- Trend over time (improving or declining)

---

#### 22. Behavior Pattern Recognition
**Effort:** 20-30 hours

**Objective:**
Learn individual's daily routines and detect deviations that may indicate health issues.

**Patterns to Learn:**
- Wake/sleep times
- Bathroom frequency
- Kitchen activity
- TV watching duration
- Time spent in bed during day (unusual)

**Anomaly Detection:**
- Sleeping much more than usual → depression, illness
- Not eating (no kitchen activity) → appetite loss
- Increased bathroom frequency → UTI, diabetes
- Unusual nighttime activity → confusion, wandering

**Implementation:**
- Collect 30+ days of baseline data
- Calculate personal "normal" ranges
- Detect statistical anomalies
- Generate alerts for significant deviations

---

### Business & Scale

#### 23. White-Label Solution
**Effort:** 50-70 hours

**Objective:**
Package moveOmeter for resale to senior living facilities, healthcare providers.

**Features:**
- Custom branding (logo, colors)
- Facility management dashboard
- Billing and subscription management
- Multi-tenant architecture
- API for integration with EMR systems
- Compliance (HIPAA, GDPR)

**Tasks:**
- [ ] Multi-tenant database design
- [ ] Billing integration (Stripe)
- [ ] Custom branding system
- [ ] Facility admin portal
- [ ] API documentation
- [ ] HIPAA compliance review
- [ ] Sales materials and demo

---

#### 24. Integration Ecosystem
**Effort:** Ongoing

**Objective:**
Integrate with other health and smart home platforms.

**Integrations:**
- **Apple Health:** Export activity data to Health app
- **Google Fit:** Sync steps and activity
- **Fitbit/Withings:** Supplement mmWave with wearable data
- **Philips Hue:** Turn on lights when person gets out of bed
- **Nest Thermostat:** Adjust temperature based on presence
- **Ring Doorbell:** Detect when person leaves/returns home
- **Electronic Health Records (EHR):** Export summaries to doctor portal
- **Pharmacy:** Medication adherence reports
- **Emergency Services:** One-button 911 integration

**Benefits:**
- More comprehensive health picture
- Better user experience
- Competitive differentiation
- Revenue opportunities (partnerships)

---

## Technical Debt

### High Priority

#### TD-1: Environment Variables for Config
**Current:** Credentials hardcoded in `config.js`
**Problem:** Must manually edit for different environments, risk of committing secrets
**Solution:** Use environment variables with build process

```javascript
// .env.production
VITE_SUPABASE_URL=https://prod.supabase.co
VITE_SUPABASE_ANON_KEY=prod_key

// .env.development
VITE_SUPABASE_URL=https://dev.supabase.co
VITE_SUPABASE_ANON_KEY=dev_key

// config.js
export const SUPABASE_CONFIG = {
  url: import.meta.env.VITE_SUPABASE_URL,
  anonKey: import.meta.env.VITE_SUPABASE_ANON_KEY
}
```

**Effort:** 2 hours

---

#### TD-2: Frontend Build System
**Current:** No bundler, no minification, manual script tags
**Problem:** Hard to manage dependencies, no tree-shaking, larger bundle sizes
**Solution:** Add Vite or similar build system

**Benefits:**
- Module imports instead of global scripts
- Minification and tree-shaking
- Hot module reload during development
- TypeScript support (optional)

**Effort:** 4-6 hours

---

#### TD-3: Automated Testing
**Current:** No automated tests, all testing manual
**Problem:** Regression bugs, slow development, fear of refactoring
**Solution:** Add test framework (Jest, Vitest)

**Test Coverage Priorities:**
1. Authentication logic
2. Data aggregation functions
3. Alert detection
4. Chart data processing
5. RLS policy validation (database tests)

**Effort:** 15-20 hours (ongoing)

---

#### TD-4: Error Handling Standardization
**Current:** Inconsistent error handling, some silent failures
**Problem:** Hard to debug, poor user experience
**Solution:** Standardize error handling pattern

```javascript
async function fetchData() {
  try {
    const { data, error } = await db.from('table').select()
    if (error) throw error
    return { success: true, data }
  } catch (error) {
    console.error('Detailed error:', error)
    showUserFriendlyError('Could not load data. Please try again.')
    logToSentry(error) // Optional: error tracking service
    return { success: false, error }
  }
}
```

**Effort:** 6-8 hours

---

### Medium Priority

#### TD-5: Code Documentation
**Current:** Minimal inline comments, no JSDoc
**Problem:** Hard for new developers to understand, hard to maintain
**Solution:** Add JSDoc comments for all functions

**Effort:** 10-15 hours

---

#### TD-6: CSS Organization
**Current:** All CSS in HTML files, duplicated styles
**Problem:** Hard to maintain consistent styling, code duplication
**Solution:** Extract to separate CSS file, use CSS variables

**Effort:** 4-6 hours

---

#### TD-7: Database Migration System
**Current:** Manual SQL scripts, hard to track what's been run
**Problem:** Can't easily reproduce database state, risky deployments
**Solution:** Use Supabase migrations or Flyway

**Effort:** 3-4 hours

---

## Feature Wishlist
Lower priority features for future consideration.

### Dashboard Enhancements
- [ ] Dark mode toggle
- [ ] Customizable dashboard layout (drag-and-drop widgets)
- [ ] Multiple chart types (line, bar, area, scatter)
- [ ] Zoom and pan on timeline charts
- [ ] Comparison mode (compare two date ranges)
- [ ] Printable reports
- [ ] Email scheduled reports
- [ ] Widget library (add new sensors easily)

### Communication Features
- [ ] In-app chat (caretaker ↔ resident)
- [ ] Video check-in (optional camera integration)
- [ ] Voice messages
- [ ] Emergency SOS button (physical button on device)
- [ ] Two-way audio (intercom feature)

### Advanced Sensors
- [ ] Door open/close sensors
- [ ] Bed pressure sensor
- [ ] Chair occupancy sensor
- [ ] Fridge door sensor (eating habits)
- [ ] Toilet flush sensor (bathroom frequency)
- [ ] Ambient light sensor (day/night cycles)
- [ ] Temperature and humidity
- [ ] Air quality monitoring

### Gamification & Engagement
- [ ] Activity goals and achievements
- [ ] Leaderboard (friendly competition)
- [ ] Rewards for healthy habits
- [ ] Virtual pet that responds to activity
- [ ] Progress tracking and milestones

### Integration & Automation
- [ ] IFTTT integration (if motion detected, then...)
- [ ] Zapier integration
- [ ] Custom webhooks
- [ ] Smart home automation
- [ ] Voice control (Alexa, Google, Siri)

---

## Scaling Roadmap

### Phase 1: Beta (Current - 10 devices)
**Database:** Supabase free tier
**Hosting:** Single Digital Ocean droplet
**Storage:** <1 GB
**Cost:** ~$10/month

**Bottlenecks:**
- None expected
- Manual deployment acceptable

**Actions:**
- Focus on features and testing
- Gather user feedback

---

### Phase 2: Early Adoption (100 devices)
**Database:** Supabase Pro (~$25/month)
**Hosting:** Digital Ocean droplet ($20/month)
**Storage:** ~10 GB
**Cost:** ~$50/month

**Bottlenecks:**
- Dashboard may slow with 100 devices shown
- Manual user onboarding time-consuming

**Actions:**
- Implement device filtering in UI
- Add automated user onboarding
- Set up monitoring (Sentry, LogRocket)

---

### Phase 3: Growth (1,000 devices)
**Database:** Supabase Pro ($25/month) or Team ($599/month)
**Hosting:** Load-balanced droplets or k8s ($100-200/month)
**Storage:** ~100 GB
**CDN:** Cloudflare (free tier)
**Cost:** ~$150-800/month

**Bottlenecks:**
- Database query performance (add read replicas)
- Real-time subscription limits
- Dashboard list of 1000 devices unusable

**Actions:**
- Implement data archival strategy
- Add search and filtering for devices
- Optimize database indexes
- Consider caching layer (Redis)
- Split into microservices if needed

---

### Phase 4: Scale (10,000 devices)
**Database:** Supabase Enterprise or self-hosted Postgres cluster
**Hosting:** Kubernetes on AWS/GCP/Azure
**Storage:** 1+ TB, S3/object storage for archives
**CDN:** Required
**Cost:** ~$2,000-5,000/month

**Bottlenecks:**
- Data ingestion rate (4M rows/day)
- Real-time updates (use message queue)
- Dashboard performance (requires caching)

**Actions:**
- Implement message queue (RabbitMQ, Kafka)
- Add caching layer (Redis, Memcached)
- Use read replicas for analytics
- Implement data partitioning
- Consider time-series database (TimescaleDB)

---

### Phase 5: Enterprise (100,000+ devices)
**Database:** Distributed database (CockroachDB, Cassandra)
**Hosting:** Multi-region cloud deployment
**Storage:** 10+ TB
**Team:** DevOps engineers, SREs required
**Cost:** $50,000+/month

**Architecture Changes:**
- Full microservices architecture
- Event-driven design
- Edge computing (process data on device)
- ML inference at scale
- Global CDN
- 24/7 monitoring and on-call

---

## Summary & Next Actions

### This Week (February 10-16)
1. ✅ Test OTA firmware update end-to-end
2. ✅ Implement browser cache-busting
3. ✅ Fix admin panel user creation (Edge Function)

### Next Week (February 17-23)
4. ✅ Add multi-device selector to dashboard
5. ✅ Enable email confirmation flow
6. ✅ Add data export (CSV/PNG)

### This Month (February 24 - March 23)
7. ✅ Responsive mobile design
8. ✅ Progressive Web App
9. ✅ Activity summary dashboard
10. ✅ Cross-browser testing

### This Quarter (April - June)
11. React Native mobile app
12. Family sharing features
13. Medication reminders
14. Scale testing (100-1000 devices)

### Priority Order
**Critical:** 1, 2, 3 (OTA, caching, user creation)
**High:** 4, 5, 6 (multi-device, email, export)
**Medium:** 7-10 (mobile, PWA, analytics, testing)
**Long-term:** 11+ (native app, AI/ML, scale)

---

**Document maintained by:** Development team
**Last review:** February 10, 2026
**Next review:** March 1, 2026
