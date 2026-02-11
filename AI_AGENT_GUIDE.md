# AI Agent Guide - moveOmeter Project

**Purpose:** This file helps AI coding assistants (Claude, GPT, Copilot, etc.) quickly understand the moveOmeter project structure, context, and how to contribute effectively.

**Last Updated:** February 10, 2026

---

## Quick Context for AI Agents

### Project Summary (30-second brief)
moveOmeter is an IoT elderly monitoring system using **ESP32-C6 + mmWave radar sensor** to track activity, sleep, and vital signs. Data uploads to **Supabase (PostgreSQL)** via WiFi every 20 seconds. A **real-time web dashboard** displays charts using Chart.js. The system supports **multi-role access** (admin/employee/caretaker/resident) with Row Level Security. Current status: **core features complete, in testing/optimization phase**.

### Technology Stack at a Glance
- **Hardware:** ESP32-C6 Feather + DFRobot SEN0623 mmWave sensor
- **Firmware:** Arduino C++ (ESPSupabase library, OTA updates enabled)
- **Backend:** Supabase (PostgreSQL + Auth + Storage + Realtime)
- **Frontend:** Vanilla JavaScript + Chart.js (no framework)
- **Deployment:** Digital Ocean Ubuntu 22.04 + Nginx at http://167.71.107.200

### Project Structure
```
moveOmeter/
├── README.md                    # Main overview and quick start
├── PROJECT_STATUS.md            # Complete current status (READ THIS FIRST)
├── ROADMAP.md                   # 6-12 month development plan
├── AI_AGENT_GUIDE.md           # This file
│
├── pictureFrame/software/
│   └── mmWave_Supabase_collector/  # ESP32-C6 Arduino firmware
│       ├── mmWave_Supabase_collector.ino  # Main firmware file
│       └── config.h                       # WiFi/Supabase credentials
│
├── web/dashboard/
│   ├── index.html              # Main dashboard page
│   ├── login.html              # Authentication page
│   ├── admin.html              # Admin panel
│   ├── dashboard.js            # Chart logic and data handling
│   ├── auth.js                 # Authentication functions
│   ├── auth-guard.js           # Route protection
│   └── config.js               # Supabase connection config
│
├── database/                    # SQL migration scripts
│   ├── setup_authentication.sql
│   ├── setup_data_access_rls.sql
│   └── run_all_migrations.sql
│
└── deployment/
    ├── deploy.sh               # Deployment script
    └── README.md               # Deployment instructions
```

---

## Understanding the Project Workflow

### Data Flow (How Everything Connects)

1. **Device → Cloud (Every 20 seconds)**
   ```
   ESP32-C6 queries mmWave sensor via UART (9600 baud)
   → Parses 40+ data fields into JSON
   → Uploads to Supabase via WiFi (ESPSupabase library)
   → Records inserted into mmwave_sensor_data table
   → device_timestamp set by ESP32-C6, created_at set by server
   ```

2. **Cloud → Dashboard (Real-time)**
   ```
   Browser opens dashboard (index.html)
   → Authenticates with Supabase Auth (if logged in)
   → Subscribes to mmwave_sensor_data table (Realtime WebSocket)
   → New data arrives → event fired
   → dashboard.js updates charts instantly
   → No polling, no page refresh needed
   ```

3. **Configuration Sync (Every 60 seconds)**
   ```
   ESP32-C6 queries moveometers table for its config
   → Checks data_collection_mode ('quick' or 'medium')
   → Adjusts sensor queries accordingly
   → Checks ota_check_interval_ms and firmware_updates table
   ```

### User Roles & Permissions (RLS)

**Role Hierarchy:**
```
admin (highest privileges)
├── Can view/edit all devices and users
├── Access to admin panel
└── Can grant/revoke permissions

employee
├── Can view all devices
├── Access to admin panel (limited)
└── Cannot manage users

caretaker
├── Can only view assigned devices (via device_access table)
├── No admin panel access
└── Read-only for their devices

caretakee (resident)
├── Can only view their own device (via caretakee_devices table)
├── No admin panel access
└── Read-only
```

**How RLS Works:**
- Queries automatically filtered by `auth.uid()` (current user's ID)
- Admins/employees: join on `user_profiles` where `role IN ('admin', 'employee')`
- Caretakers: join on `device_access` table where `user_id = auth.uid()`
- Caretakees: join on `caretakee_devices` table where `caretakee_id = auth.uid()`

---

## Key Implementation Details AI Should Know

### 1. Timeline Data Aggregation (Performance Critical)

**Problem Solved:** Rendering 1000+ data points caused browser lag.

**Solution:** Time-based bucketing
- **1-hour timeline:** No aggregation (raw data, max 180 points)
- **12-hour timeline:** 5-minute buckets (~144 points, was 2160)
- **24-hour timeline:** 10-minute buckets (~144 points, was 4320)

**Aggregation Logic:**
```javascript
function aggregateDataByTime(rawData, bucketSizeMs) {
  const buckets = new Map();

  rawData.forEach(point => {
    const timestamp = new Date(point.device_timestamp || point.created_at);
    const bucketKey = Math.floor(timestamp.getTime() / bucketSizeMs) * bucketSizeMs;

    if (!buckets.has(bucketKey)) buckets.set(bucketKey, []);
    buckets.get(bucketKey).push(point);
  });

  return Array.from(buckets.entries()).map(([bucketKey, points]) => ({
    timestamp: new Date(bucketKey),
    human_existence: Math.max(...points.map(p => p.human_existence || 0)), // MAX
    motion_detected: Math.max(...points.map(p => p.motion_detected || 0)),  // MAX
    body_movement: Math.round(points.reduce((sum, p) => sum + (p.body_movement || 0), 0) / points.length) // AVERAGE
  }));
}
```

**Why MAX for existence/motion?** Don't want to miss any activity.
**Why AVERAGE for body_movement?** Smooths out spikes, shows general trend.

---

### 2. Query Ordering Fix (Critical Bug Fixed)

**Previous Bug:**
```javascript
// WRONG - Gets oldest 1000 records
.order('device_timestamp', { ascending: true })
.limit(1000)
// Result: Data from midnight to 1 AM only (oldest data)
```

**Current Fix:**
```javascript
// CORRECT - Gets newest 1000 records, then reverses
.order('device_timestamp', { ascending: false })
.limit(10000) // Increased limit
// Then: data.reverse() to get chronological order
```

**AI Agent Note:** Always query descending and reverse, especially for time series data with limits.

---

### 3. Smart Keep-Alive Optimization

**Problem:** Uploading full sensor data every 20s wastes bandwidth when room is empty.

**Solution:**
```cpp
// In Arduino firmware:
uint16_t movement = sensor.smHumanData(eHumanMovingRange);
uint16_t humanPresence = sensor.smHumanData(eHumanPresence);
bool hasActivity = (movement > 0 || humanPresence > 0);

if (!hasActivity) {
  // Send minimal keep-alive every 30 seconds
  if (currentTime - lastKeepAliveTime >= 30000) {
    uint8_t fallState = sensor.getFallData(eFallState); // Safety check
    json = "{\"data_type\":\"keep_alive\",\"body_movement\":0,\"human_existence\":0,\"fall_state\":" + String(fallState) + "}";
    uploadData(json);
    lastKeepAliveTime = currentTime;
  }
  return; // Don't collect full data
}

// Full data collection when activity detected
```

**Result:** 97% bandwidth reduction during idle periods, while still monitoring for falls.

---

### 4. Device Timestamp vs Server Timestamp

**Important:** Use `device_timestamp` for time series queries, not `created_at`.

**Why?**
- `created_at`: When Supabase received the data (may be delayed by network)
- `device_timestamp`: When ESP32-C6 recorded the data (accurate to milliseconds)

**Usage:**
```javascript
// CORRECT
.gte('device_timestamp', startTime)
.lte('device_timestamp', endTime)
.not('device_timestamp', 'is', null) // Filter out NULL
.order('device_timestamp', { ascending: false })

// WRONG
.gte('created_at', startTime) // Don't use for timelines
```

**Edge Case:** Some old data may have `device_timestamp = NULL`. Filter it out.

---

### 5. OTA Firmware Update Process

**Status:** Infrastructure complete, needs end-to-end testing.

**How It Works:**
1. Admin uploads new firmware .bin to Supabase Storage
2. Admin creates record in `firmware_updates` table:
   ```sql
   INSERT INTO firmware_updates (version, device_model, download_url, md5_checksum, mandatory)
   VALUES ('1.0.1', 'ESP32C6_MOVEOMETER', 'https://...', 'abc123...', false);
   ```
3. ESP32-C6 checks every hour (configurable via `ota_check_interval_ms`)
4. Compares current version with latest in database
5. If newer version exists:
   - Downloads .bin file over HTTPS
   - Verifies MD5 checksum
   - Flashes to OTA partition
   - Reboots into new firmware
   - Auto-rollback if boot fails

**Partition Scheme Required:** "Minimal SPIFFS (1.9MB APP with OTA/190KB SPIFFS)"

**Testing Guide:** See `/database/OTA_QUICK_TEST.md`

---

## Common Patterns & Best Practices

### 1. Querying Supabase from Dashboard

**Standard Pattern:**
```javascript
async function fetchData() {
  try {
    const { data, error } = await db
      .from('table_name')
      .select('columns')
      .eq('device_id', deviceId) // Always filter by device
      .order('device_timestamp', { ascending: false })
      .limit(1000);

    if (error) throw error;

    // Success
    return data.reverse(); // Chronological order
  } catch (error) {
    console.error('Error fetching data:', error);
    showUserMessage('Failed to load data. Please refresh.', 'error');
    return [];
  }
}
```

**Always:**
- Check for `error` in response
- Handle errors gracefully with user-friendly messages
- Filter by `device_id` unless admin viewing all
- Use try-catch for network errors
- Return empty array on error (don't crash UI)

---

### 2. Adding New Sensor Fields

**To add a new sensor metric (e.g., "ambient_temperature"):**

1. **Update Database Schema:**
   ```sql
   ALTER TABLE mmwave_sensor_data
   ADD COLUMN ambient_temperature INTEGER;
   ```

2. **Update Arduino Firmware:**
   ```cpp
   // In collectAndUploadMediumData():
   uint16_t temp = sensor.getTemperature(); // Or appropriate function
   json += ",\"ambient_temperature\":" + String(temp);
   ```

3. **Update Dashboard (if displaying):**
   ```javascript
   // In dashboard.js, add to metric cards or chart
   const temp = latestData.ambient_temperature;
   document.getElementById('temp-value').textContent = temp + '°C';
   ```

4. **Update Documentation:**
   - Add to sensor field list in README.md
   - Document range and units
   - Update PROJECT_STATUS.md if significant feature

---

### 3. Handling Real-Time Subscriptions

**Pattern:**
```javascript
// Subscribe to new data
const subscription = db
  .channel('sensor-data')
  .on('postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'mmwave_sensor_data',
      filter: `device_id=eq.${deviceId}` // Filter server-side
    },
    (payload) => {
      const newData = payload.new;
      handleNewData(newData); // Update charts
    }
  )
  .subscribe();

// Clean up on page unload
window.addEventListener('beforeunload', () => {
  subscription.unsubscribe();
});
```

**Important:**
- Always filter subscriptions by `device_id` to reduce bandwidth
- Unsubscribe when component unmounts/page closes
- Handle connection loss gracefully (reconnect logic)

---

### 4. Role-Based UI Elements

**Pattern:**
```javascript
// In auth-guard.js or similar
const userRole = window.currentUser?.role;

// Show/hide admin button
if (['admin', 'employee'].includes(userRole)) {
  document.getElementById('admin-btn').style.display = 'block';
} else {
  document.getElementById('admin-btn').style.display = 'none';
}

// Check before admin actions
function deleteUser(userId) {
  if (userRole !== 'admin') {
    alert('Only admins can delete users');
    return;
  }
  // Proceed with deletion
}
```

**Security Note:** UI hiding is UX, not security. RLS policies enforce actual permissions.

---

## File-Specific Guidance

### Working with `mmWave_Supabase_collector.ino`

**Key Sections:**
```cpp
// 1. Configuration (lines ~20-50)
#define FIRMWARE_VERSION "1.0.0"
#define DATA_INTERVAL 20000 // milliseconds
#define KEEP_ALIVE_INTERVAL 30000

// 2. Sensor initialization (setup())
if (!sensor.begin(Serial1)) {
  USB_SERIAL.println("Sensor init failed");
  while(1); // Halt
}

// 3. WiFi connection (connectWiFi())
WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
// Auto-reconnect logic included

// 4. Data collection (loop())
if (deviceConfig.dataCollectionMode == "quick") {
  collectAndUploadQuickData();
} else {
  collectAndUploadMediumData();
}

// 5. Configuration sync (fetchDeviceConfig())
// Runs every 60 seconds
// Updates deviceConfig struct from database

// 6. OTA updates (checkForFirmwareUpdate())
// Runs every ota_check_interval_ms (default 1 hour)
```

**When Modifying:**
- Always increment `FIRMWARE_VERSION` after changes
- Test with Serial Monitor at 115200 baud
- Use `USB_SERIAL.println()` for debugging (not `Serial.println()`)
- Remember partition scheme: Minimal SPIFFS (1.9MB APP with OTA)

**Common Sensor Functions:**
```cpp
// Human presence (0 or 1)
sensor.smHumanData(eHumanPresence)

// Movement range (0-100)
sensor.smHumanData(eHumanMovingRange)

// Body movement intensity (0-100)
sensor.smHumanData(eHumanMovement)

// Heart rate (BPM)
sensor.getBedData(eHeartRate)

// Respiration rate
sensor.getBedData(eBreathValue)

// Fall detection
sensor.getFallData(eFallState) // 0=no fall, 1=fall detected
```

---

### Working with `dashboard.js`

**Key Functions:**

1. **Data Loading:**
   ```javascript
   async function loadTimelineData() {
     // Loads historical data for charts
     // Called on page load and device change
   }
   ```

2. **Real-Time Updates:**
   ```javascript
   function setupRealtimeSubscription() {
     // Subscribes to new data
     // Updates charts automatically
   }
   ```

3. **Chart Updates:**
   ```javascript
   function update1HourTimeline(newData)
   function update12HourTimeline(newData) // Uses aggregation
   function update24HourTimeline(newData) // Uses aggregation
   ```

4. **Device Status:**
   ```javascript
   function checkDeviceOnlineStatus() {
     // Runs every 5 seconds
     // Shows "Online" or "Offline (X seconds ago)"
     // Hides metrics when offline
   }
   ```

**Global Variables AI Should Know:**
```javascript
const db = createClient(url, key); // Supabase client
let currentDeviceId = 'ESP32C6_001'; // Selected device
let timeline1HourBuffer = []; // Raw data for 1-hour chart
let timeline12HourBuffer = []; // Raw data for 12-hour chart
let timeline24HourBuffer = []; // Raw data for 24-hour chart
```

---

### Working with Database Migrations

**Order of Execution:**
1. `setup_authentication.sql` - Creates tables, RLS policies, triggers
2. `setup_data_access_rls.sql` - Additional RLS policies for device access
3. `create_annotations_only.sql` - Adds annotations table
4. Various `fix_*.sql` - Bug fixes and improvements

**To Add New Migration:**
1. Create new file: `database/feature_name.sql`
2. Add clear comments explaining what and why
3. Include rollback instructions (how to undo)
4. Update `run_all_migrations.sql` to include it
5. Test on dev Supabase project first
6. Document in PROJECT_STATUS.md

**Migration Template:**
```sql
-- Migration: Add feature X
-- Date: 2026-02-XX
-- Purpose: Explain why this change is needed

-- Table creation
CREATE TABLE IF NOT EXISTS table_name (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  -- other fields
);

-- Indexes
CREATE INDEX idx_name ON table_name(column);

-- RLS Policies
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

CREATE POLICY "policy_name"
ON table_name
FOR SELECT
USING (auth.uid() = user_id);

-- Triggers (if needed)
CREATE OR REPLACE FUNCTION trigger_function()
RETURNS TRIGGER AS $$
BEGIN
  -- Logic here
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_name
AFTER INSERT ON table_name
FOR EACH ROW
EXECUTE FUNCTION trigger_function();

-- Rollback instructions:
-- DROP TABLE table_name;
-- DROP FUNCTION trigger_function();
```

---

## Decision-Making Guidelines for AI Agents

### When to Create New Files vs Modify Existing

**Create New File When:**
- Adding entirely new feature (new page, new component)
- Creating documentation (new guide, new setup instructions)
- Adding database migration (always separate file)

**Modify Existing File When:**
- Fixing bugs in existing functionality
- Adding fields to existing forms
- Improving existing features
- Updating documentation for current features

### When to Ask User vs Decide Autonomously

**Always Ask User:**
- Breaking changes (changing function signatures, removing features)
- Database schema changes (adding/removing columns)
- Security-related changes (authentication, permissions)
- Architecture changes (switching libraries, frameworks)
- UI/UX changes that affect user workflow
- Deployment changes (server configuration, DNS)

**Decide Autonomously (with explanation):**
- Bug fixes (if root cause is clear)
- Performance optimizations (if no breaking changes)
- Code refactoring (if behavior unchanged)
- Documentation improvements
- Adding comments or logging
- Consistent styling/formatting

### Code Style Preferences

**JavaScript:**
- Use `const` and `let`, never `var`
- Use async/await, not Promise chains
- Use template literals: \`${variable}\` not `"" + variable + ""`
- Use arrow functions for callbacks
- Comment complex logic

**Arduino C++:**
- Use `USB_SERIAL.println()` not `Serial.println()`
- Always check return values (WiFi.status(), sensor.begin())
- Use `unsigned long` for timestamps (millis())
- Define constants at top of file
- Keep functions focused (single responsibility)

**SQL:**
- Use uppercase for keywords (SELECT, FROM, WHERE)
- Include IF NOT EXISTS for safety
- Comment complex queries
- Always specify schema (public.table_name)
- Include rollback instructions

**HTML/CSS:**
- Semantic HTML (use `<section>`, `<article>`, not just `<div>`)
- Responsive design (mobile-first)
- Accessibility (ARIA labels, alt text)
- Consistent naming (kebab-case for classes)

---

## Testing Guidelines

### How to Verify Changes Work

**Firmware Changes:**
1. Compile in Arduino IDE (verify no errors)
2. Upload to ESP32-C6
3. Open Serial Monitor (115200 baud)
4. Look for success messages:
   ```
   WiFi connected
   Supabase initialized
   Data uploaded: SUCCESS!
   ```
5. Check Supabase table for new data
6. Verify dashboard displays new data

**Dashboard Changes:**
1. Open browser Developer Tools (F12)
2. Check Console for errors
3. Check Network tab for failed requests
4. Test with hard refresh (Ctrl+Shift+R)
5. Test in incognito/private window (cache bypass)
6. Test on different browser (Chrome, Firefox, Safari)

**Database Changes:**
1. Run migration on test project first
2. Verify tables created: `\dt` in SQL editor
3. Test INSERT/SELECT queries
4. Verify RLS policies work (test as different roles)
5. Check triggers fire correctly
6. Backup before running on production

### Common Issues & How to Debug

**Issue: Dashboard shows "Disconnected"**
```
Debug steps:
1. Check browser console for errors
2. Verify config.js has correct Supabase URL/key
3. Test Supabase connection:
   const { data } = await db.from('moveometers').select().limit(1)
   console.log(data)
4. Check Supabase dashboard → Logs for errors
```

**Issue: Firmware won't compile**
```
Debug steps:
1. Verify libraries installed (ESPSupabase, DFRobot_HumanDetection)
2. Check board selected: ESP32C6 Dev Module
3. Check partition: Minimal SPIFFS (1.9MB APP with OTA)
4. Read error message carefully (line number, missing function)
5. Check for typos in function names (case-sensitive)
```

**Issue: Data not appearing in database**
```
Debug steps:
1. Check Serial Monitor for upload status
2. Look for "SUCCESS!" message
3. If "FAILED", check error code (401, 404, 500)
4. 401 = wrong API key
5. 404 = table doesn't exist or wrong name
6. 500 = server error (check Supabase logs)
7. Test with manual INSERT in SQL editor
```

**Issue: RLS denying access**
```
Debug steps:
1. Check which user is authenticated: auth.uid()
2. Check user's role in user_profiles
3. Review RLS policy for table:
   SELECT * FROM pg_policies WHERE tablename = 'table_name';
4. Test policy manually:
   SELECT * FROM table_name WHERE <policy condition>;
5. Temporarily disable RLS for testing:
   ALTER TABLE table_name DISABLE ROW LEVEL SECURITY;
   (Don't forget to re-enable!)
```

---

## Integration Points (How Systems Connect)

### ESP32-C6 ↔ Supabase

**Connection:**
```cpp
#include <ESPSupabase.h>

Supabase db;
db.begin(SUPABASE_URL, SUPABASE_ANON_KEY);

// Insert data
String json = "{\"device_id\":\"ESP32C6_001\",\"value\":123}";
int code = db.insert(SUPABASE_TABLE, json, false);
// code: 201 = success, 401 = unauthorized, 404 = table not found
```

**Authentication:** Uses anon key (safe for device inserts, RLS allows public insert)

---

### Dashboard ↔ Supabase

**Connection:**
```javascript
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'

const db = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);

// Authenticated request (after login)
const { data, error } = await db.from('table').select('*');
// RLS automatically enforces permissions based on logged-in user
```

**Authentication:** Uses Supabase Auth (email/password), session stored in localStorage

---

### Real-Time Data Flow

**Sequence:**
```
1. ESP32-C6 inserts row into mmwave_sensor_data
2. Supabase broadcasts INSERT event via WebSocket
3. Dashboard receives event (if subscribed)
4. Dashboard.js calls handleNewData(payload.new)
5. Charts update with new data point
6. UI shows updated timestamp
```

**Subscription Setup:**
```javascript
db.channel('changes')
  .on('postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'mmwave_sensor_data' },
    handleNewData
  )
  .subscribe()
```

---

## Scaling Considerations for AI Agents

### Current Limitations (10 devices)
- Single dashboard page (no pagination)
- No caching layer
- Direct database queries
- Real-time subscription per device

### At 100 Devices
- Need device search/filter
- Consider query result caching
- Aggregate metrics (don't load all devices at once)

### At 1,000 Devices
- Require read replicas
- Implement Redis caching
- Background jobs for analytics
- Message queue for data ingestion

### At 10,000+ Devices
- Microservices architecture
- Time-series database (TimescaleDB)
- Distributed tracing
- Edge computing (process on device)

**AI Agent Note:** When adding features, consider "will this work at 10,000 devices?" If not, document the scaling limitation.

---

## Deployment Workflow

### Local Development
```bash
# 1. Start local dashboard
cd web/dashboard
python3 -m http.server 8000

# 2. Open browser
open http://localhost:8000

# 3. Make changes to HTML/JS/CSS
# 4. Hard refresh browser (Cmd+Shift+R)

# 5. Test with Serial Monitor for firmware
# Arduino IDE → Tools → Serial Monitor (115200 baud)
```

### Deploying to Production
```bash
# From deployment directory
cd deployment
./deploy.sh deploy@167.71.107.200

# This:
# 1. Uploads files to /tmp/moveometer-deploy/
# 2. Copies to /var/www/moveometer/
# 3. Sets permissions (www-data:www-data)
# 4. Reloads Nginx
```

### Versioning Strategy
- Firmware: Increment `FIRMWARE_VERSION` in .ino file
- Dashboard: No versioning yet (TODO: add version.js)
- Database: Migration files dated and numbered

---

## Quick Reference Cheat Sheet

### Arduino Sensor Queries
| Function | Purpose | Return Type |
|----------|---------|-------------|
| `sensor.smHumanData(eHumanPresence)` | Is person present? | 0 or 1 |
| `sensor.smHumanData(eHumanMovement)` | Movement intensity | 0-100 |
| `sensor.smHumanData(eHumanMovingRange)` | Movement range | 0-100 |
| `sensor.getBedData(eHeartRate)` | Heart rate | BPM (0-255) |
| `sensor.getBedData(eBreathValue)` | Respiration | breaths/min |
| `sensor.getFallData(eFallState)` | Fall detected? | 0 or 1 |

### Supabase Table Reference
| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `mmwave_sensor_data` | Time series sensor data | device_timestamp, device_id, human_existence, body_movement |
| `moveometers` | Device registry | device_id, data_collection_mode, firmware_version, ota_status |
| `user_profiles` | User accounts | id, email, role, full_name, is_active |
| `device_access` | Permissions | user_id, device_id, access_level |
| `firmware_updates` | OTA versions | version, download_url, md5_checksum |
| `audit_log` | Security events | user_id, action, success, created_at |
| `annotations` | Timeline notes | device_id, annotation_time, text, annotation_type |

### JavaScript Supabase Queries
```javascript
// Select with filter
const { data, error } = await db
  .from('table')
  .select('*')
  .eq('column', value)
  .order('created_at', { ascending: false })
  .limit(100);

// Insert
const { data, error } = await db
  .from('table')
  .insert({ column1: value1, column2: value2 });

// Update
const { data, error } = await db
  .from('table')
  .update({ column: newValue })
  .eq('id', recordId);

// Delete
const { data, error } = await db
  .from('table')
  .delete()
  .eq('id', recordId);

// Subscribe to changes
const subscription = db
  .channel('channel-name')
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'table_name' }, callback)
  .subscribe();
```

---

## Important Context for Specific Tasks

### If Asked to Add New Chart
1. Add `<canvas id="newChart"></canvas>` to index.html
2. Initialize Chart.js in dashboard.js:
   ```javascript
   const newChart = new Chart(document.getElementById('newChart'), {
     type: 'line',
     data: { labels: [], datasets: [{ label: 'Metric', data: [] }] },
     options: { responsive: true }
   });
   ```
3. Update chart in real-time handler:
   ```javascript
   function updateNewChart(newData) {
     newChart.data.labels.push(newData.timestamp);
     newChart.data.datasets[0].data.push(newData.value);
     newChart.update();
   }
   ```

### If Asked to Add New User Role
1. Update `user_profiles.role` check constraint in database:
   ```sql
   ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;
   ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check
     CHECK (role IN ('admin', 'employee', 'caretaker', 'caretakee', 'new_role'));
   ```
2. Add RLS policy for new role
3. Update auth-guard.js to handle new role
4. Update UI role-based visibility logic
5. Document in AUTH_SETUP.md

### If Asked to Add New Sensor Metric
See "Adding New Sensor Fields" section above.

### If Asked to Optimize Performance
1. Check current bottleneck (use browser Performance tab)
2. Common optimizations:
   - Data aggregation (already implemented for timelines)
   - Lazy loading (load data only when needed)
   - Virtual scrolling (for long lists)
   - Debouncing (for frequent events)
   - Caching (localStorage for static data)
   - Minification (use build tool)
3. Document before/after metrics

---

## Glossary of Project-Specific Terms

- **mmWave:** Millimeter wave radar technology (privacy-preserving, no camera)
- **SEN0623:** DFRobot mmWave sensor model number
- **ESP32-C6:** Microcontroller with WiFi and Bluetooth
- **Supabase:** Backend-as-a-Service (PostgreSQL + Auth + Storage + Realtime)
- **RLS:** Row Level Security (PostgreSQL feature for data isolation)
- **OTA:** Over-The-Air firmware updates
- **Keep-alive:** Minimal data upload when no activity (bandwidth optimization)
- **Device timestamp:** When ESP32-C6 recorded data (accurate for time series)
- **Created timestamp:** When Supabase received data (may be delayed)
- **Quick mode:** Minimal sensor queries (battery saver)
- **Medium mode:** Full sensor suite (when presence detected)
- **Annotation:** User-added note on timeline
- **Aggregation:** Grouping data into time buckets (performance optimization)

---

## Final Notes for AI Agents

**Philosophy:**
- Privacy-first (no cameras, no wearables)
- Simple before complex (vanilla JS before framework)
- User-friendly (non-technical caregivers)
- Scalable (design for millions, build for hundreds)
- Secure (RLS, authentication, audit logging)

**When in Doubt:**
1. Read PROJECT_STATUS.md for current state
2. Check ROADMAP.md for planned direction
3. Review relevant documentation in /database/ or /web/
4. Ask user if decision has long-term implications

**Success Criteria:**
- Code works on first try (test before suggesting)
- Changes don't break existing features (test regression)
- Performance is maintained or improved
- Security is maintained or improved
- Documentation is updated

**AI Agent Motto:** "Make it work, make it right, make it fast, make it documented."

---

**This guide will be updated as the project evolves. Last updated: February 10, 2026**
