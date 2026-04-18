# Analytics Implementation Guide

This guide explains how to implement and use the moveOmeter analytics system for tracking user behavior on both web and mobile platforms.

## Overview

The analytics system tracks:
- **User sessions** (login times, duration, activity)
- **User actions** (button clicks, page views, interactions)
- **App usage** (version tracking, platform, device info)
- **Aggregated metrics** (total logins, average session duration, popular features)

## Database Setup

### 1. Create Analytics Tables

Run this SQL in Supabase SQL Editor:

```bash
/database/create_analytics_tables.sql
```

This creates:
- `user_sessions` - Web dashboard sessions
- `user_actions` - Detailed action log for web
- `user_login_stats` - Aggregated user statistics
- `app_sessions` - Mobile app sessions
- `app_actions` - Detailed action log for mobile
- `app_usage_stats` - Aggregated app usage stats

## Web Dashboard Implementation

### 2. Add Analytics Script to Dashboard

Add to `web/dashboard/index.html` before closing `</head>`:

```html
<script src="analytics.js"></script>
```

### 3. Initialize Analytics After Login

In `web/dashboard/dashboard.js`, after successful login:

```javascript
// After user logs in successfully
const { data: { user } } = await supabase.auth.getUser();
if (user) {
    // Initialize analytics
    initializeAnalytics(supabase, user.id);
}
```

### 4. Track User Actions

Add tracking calls throughout your dashboard code:

```javascript
// Track button clicks
document.getElementById('admin-btn').addEventListener('click', () => {
    trackAction('button_click', 'navigation', 'admin_button');
    // ... existing code
});

// Track mode switches
function switchMode(newMode) {
    trackAction('mode_switch', 'settings', 'operational_mode', newMode);
    // ... existing code
}

// Track chart interactions
charts.timeline12Hour.options.plugins.zoom.onZoomComplete = function() {
    trackAction('chart_interaction', 'data_view', 'timeline_12h', 'zoom');
};

// Track device views
function viewDevice(deviceId) {
    trackAction('device_view', 'device_management', deviceId);
    // ... existing code
}

// Track annotation creation
function createAnnotation(type) {
    trackAction('annotation_create', 'data_annotation', type);
    // ... existing code
}
```

## Mobile App Implementation

### 5. Import Analytics Service

Add to your Flutter page imports:

```dart
import '../services/analytics_service.dart';
```

### 6. Start Session on App Launch

In `main.dart` or your main app widget:

```dart
@override
void initState() {
  super.initState();
  // Start analytics session after login
  analyticsService.startSession();
}

@override
void dispose() {
  // End session when app closes
  analyticsService.endSession();
  super.dispose();
}
```

### 7. Track Screen Views

Add to the `initState()` of each page:

```dart
@override
void initState() {
  super.initState();
  analyticsService.trackScreenView('HousesPage');
}
```

### 8. Track User Actions

Add tracking calls throughout your app:

```dart
// Track button taps
ElevatedButton(
  onPressed: () {
    analyticsService.trackButtonTap('add_house_button',
      screenName: 'HousesPage');
    // ... existing code
  },
  child: Text('Add House'),
)

// Track device actions
void addDevice() async {
  analyticsService.trackDeviceAction('add_device', deviceId,
    screenName: 'DevicesPage');
  // ... existing code
}

// Track BLE provisioning steps
void startProvisioning() {
  analyticsService.trackBLEProvisioning('start',
    deviceId: deviceId,
    screenName: 'ScanDevicesPage');
  // ... existing code
}

// Track house views
void viewHouse(String houseId) {
  analyticsService.trackHouseView(houseId,
    screenName: 'HouseDayDetailPage');
  // ... existing code
}

// Track login/logout
void login() async {
  // ... login code
  await analyticsService.trackLogin();
  await analyticsService.startSession();
}

void logout() async {
  await analyticsService.trackLogout();
  // ... logout code
}
```

## Viewing Analytics Data

### Query Examples

**Most active users (total logins):**
```sql
SELECT
  u.email,
  s.total_logins,
  s.last_login_at,
  s.average_session_duration_seconds / 60 as avg_session_minutes
FROM user_login_stats s
JOIN auth.users u ON u.id = s.user_id
ORDER BY s.total_logins DESC
LIMIT 10;
```

**Recent user actions:**
```sql
SELECT
  u.email,
  a.action_type,
  a.action_target,
  a.created_at
FROM user_actions a
JOIN auth.users u ON u.id = a.user_id
ORDER BY a.created_at DESC
LIMIT 50;
```

**App version distribution:**
```sql
SELECT
  app_platform,
  current_version,
  COUNT(*) as user_count
FROM app_usage_stats
GROUP BY app_platform, current_version
ORDER BY app_platform, user_count DESC;
```

**Active sessions now:**
```sql
SELECT
  u.email,
  s.session_start,
  s.page_views,
  s.actions_count,
  s.browser,
  s.device_type
FROM user_sessions s
JOIN auth.users u ON u.id = s.user_id
WHERE s.session_end IS NULL
  AND s.session_start > NOW() - INTERVAL '1 hour'
ORDER BY s.session_start DESC;
```

**Popular features (most clicked buttons):**
```sql
SELECT
  action_target,
  COUNT(*) as click_count
FROM user_actions
WHERE action_type = 'button_click'
  AND created_at > NOW() - INTERVAL '7 days'
GROUP BY action_target
ORDER BY click_count DESC
LIMIT 10;
```

**App engagement metrics:**
```sql
SELECT
  app_platform,
  COUNT(DISTINCT user_id) as active_users,
  AVG(total_sessions) as avg_sessions_per_user,
  AVG(total_session_duration_seconds / 60) as avg_total_minutes
FROM app_usage_stats
WHERE last_used_at > NOW() - INTERVAL '30 days'
GROUP BY app_platform;
```

## Tracked Metrics

### Web Dashboard

| Metric | Description |
|--------|-------------|
| **Session Start/End** | When user logs in/out or closes tab |
| **Session Duration** | Total time spent in dashboard |
| **Page Views** | Number of different pages/views |
| **Actions Count** | Total interactions (clicks, zooms, etc.) |
| **Browser/OS** | User's browser and operating system |
| **Device Type** | Desktop, tablet, or mobile |
| **IP Address** | User's IP for geo-location |
| **Button Clicks** | Which buttons were clicked |
| **Chart Interactions** | Zoom, pan, hover on charts |
| **Mode Switches** | Sleep ↔ Fall Detection mode changes |
| **Device Views** | Which devices were viewed |

### Mobile App

| Metric | Description |
|--------|-------------|
| **Session Start/End** | When app opens/closes |
| **Session Duration** | Total time in app |
| **App Version** | Which version user is on |
| **Platform** | iOS or Android |
| **Device Model** | Phone/tablet model |
| **OS Version** | iOS/Android version |
| **Screens Viewed** | Number of screens navigated |
| **Actions Count** | Total interactions |
| **Button Taps** | Which buttons were tapped |
| **Screen Views** | Which screens were viewed |
| **Device Actions** | Add, remove, configure devices |
| **BLE Provisioning** | Setup flow tracking |

## Privacy & Security

- All analytics data is user-specific and protected by RLS (Row Level Security)
- Users can only see their own analytics data
- Employees/admins will need separate policies to view aggregate analytics
- IP addresses are collected but can be anonymized if needed
- No personally identifiable information (PII) is stored in action logs

## Next Steps

1. **Run the SQL** to create analytics tables
2. **Update web dashboard** to include analytics.js
3. **Add tracking calls** to dashboard.js
4. **Update mobile app** to use analytics_service.dart
5. **Add tracking calls** throughout Flutter app
6. **Create admin analytics dashboard** to view metrics
7. **Set up periodic reports** (daily/weekly email summaries)

## Future Enhancements

- **Heatmaps** - Visual representation of most-clicked areas
- **Funnel analysis** - Track user flow through features
- **Cohort analysis** - Compare user groups over time
- **A/B testing** - Test different UI variations
- **Crash reporting** - Track app crashes and errors
- **Performance monitoring** - Track load times, API response times
