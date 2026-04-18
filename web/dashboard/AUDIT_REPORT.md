# Dashboard Code Audit Report
**Date:** April 12, 2026
**Audited Files:** dashboard.js, auth-guard.js, config.js, analytics.js, caretaker_management.js, index.html

## 🔴 CRITICAL ISSUES

### 1. Memory Leaks from Uncleaned Intervals
**Location:** dashboard.js lines 158, 161, 168; analytics.js line 234
**Severity:** HIGH
**Impact:** Over time, multiple intervals accumulate causing performance degradation and eventual browser crash

**Problem:**
```javascript
// dashboard.js:158
setInterval(loadLatestData, DASHBOARD_CONFIG.refreshInterval);

// dashboard.js:161
setInterval(async () => {
    await load12HourData();
    await load24HourData();
}, 2 * 60 * 1000);

// dashboard.js:168
setInterval(checkDeviceOnlineStatus, 2000);

// analytics.js:234
setInterval(() => {
    if (analytics) {
        analytics.updateSessionMetrics();
    }
}, 30000);
```

**Issue:** None of these intervals are ever cleared. If the page is reloaded, navigated away from, or if the initialization code runs multiple times, these intervals keep running in the background.

**Fix Required:**
- Store interval IDs in variables
- Clear intervals on page unload or before creating new ones
- Implement cleanup on navigation

**Recommendation:**
```javascript
let refreshIntervalId = null;
let timelineIntervalId = null;
let statusIntervalId = null;

// Clear old intervals before creating new ones
if (refreshIntervalId) clearInterval(refreshIntervalId);
if (timelineIntervalId) clearInterval(timelineIntervalId);
if (statusIntervalId) clearInterval(statusIntervalId);

refreshIntervalId = setInterval(loadLatestData, DASHBOARD_CONFIG.refreshInterval);
timelineIntervalId = setInterval(async () => { ... }, 2 * 60 * 1000);
statusIntervalId = setInterval(checkDeviceOnlineStatus, 2000);

// Add cleanup on page unload
window.addEventListener('beforeunload', () => {
    clearInterval(refreshIntervalId);
    clearInterval(timelineIntervalId);
    clearInterval(statusIntervalId);
});
```

---

### 2. Hardcoded Device ID Throughout Codebase
**Location:** Multiple files
**Severity:** HIGH
**Impact:** Dashboard only works for one specific device (ESP32C6_001)

**Problem:**
- config.js line 15: `deviceId: 'ESP32C6_001'`
- Multiple database queries filter by this hardcoded ID
- No way for users with multiple devices to switch between them
- No way to view different houses/devices

**Fix Required:**
- Implement device selection UI
- Store selected device ID in session/localStorage
- Query user's accessible devices from database
- Allow switching between devices

---

### 3. Missing Analytics Error Handling
**Location:** auth-guard.js line 56, dashboard.js multiple locations
**Severity:** MEDIUM-HIGH
**Impact:** If analytics.js fails to load or analytics is undefined, dashboard crashes

**Problem:**
```javascript
// auth-guard.js:56
initializeAnalytics(authClient, session.user.id);  // No try-catch

// auth-guard.js:75-77
if (analytics) {
    await analytics.endSession();  // Assumes analytics exists
}

// dashboard.js: multiple trackAction() calls
trackAction('mode_switch', 'settings', 'operational_mode', mode);
// If analytics.js didn't load, trackAction is undefined -> crash
```

**Fix Required:**
```javascript
// Wrap in try-catch
try {
    if (typeof initializeAnalytics === 'function') {
        initializeAnalytics(authClient, session.user.id);
    }
} catch (err) {
    console.error('Analytics initialization failed:', err);
    // Continue without analytics
}

// Safe trackAction
function safeTrackAction(...args) {
    try {
        if (typeof trackAction === 'function') {
            trackAction(...args);
        }
    } catch (err) {
        console.error('Analytics tracking failed:', err);
    }
}
```

---

### 4. Chart Plugin Dependencies Not Checked
**Location:** dashboard.js lines 667-1050 (chart initialization)
**Severity:** MEDIUM
**Impact:** Dashboard crashes if Chart.js plugins fail to load

**Problem:**
```javascript
// dashboard.js assumes chartjs-plugin-annotation exists
chart.options.plugins.annotation = { annotations: {} };
```

**Issue:** If CDN fails to load chartjs-plugin-annotation, all annotation features crash

**Fix Required:**
```javascript
// Check if plugin is available
if (typeof Chart.Annotation !== 'undefined') {
    chart.options.plugins.annotation = { annotations: {} };
} else {
    console.warn('Chart annotation plugin not available');
}
```

---

### 5. No Retry Logic for Failed Database Queries
**Location:** All database query locations
**Severity:** MEDIUM
**Impact:** Temporary network issues cause complete dashboard failure

**Problem:**
```javascript
const { data, error } = await db.from('moveometers').select('*');
if (error) throw error;  // Immediate failure, no retry
```

**Fix Required:**
Implement exponential backoff retry logic:
```javascript
async function queryWithRetry(queryFn, maxRetries = 3) {
    for (let i = 0; i < maxRetries; i++) {
        try {
            const result = await queryFn();
            if (result.error) {
                if (i === maxRetries - 1) throw result.error;
                await new Promise(r => setTimeout(r, 1000 * Math.pow(2, i)));
                continue;
            }
            return result;
        } catch (err) {
            if (i === maxRetries - 1) throw err;
            await new Promise(r => setTimeout(r, 1000 * Math.pow(2, i)));
        }
    }
}
```

---

### 6. Realtime Subscription Never Cleaned Up
**Location:** dashboard.js line 1355
**Severity:** MEDIUM
**Impact:** Orphaned subscriptions accumulate, causing memory leaks and duplicate events

**Problem:**
```javascript
function setupRealtimeSubscription() {
    const channel = db.channel('mmwave_changes')
        .on('postgres_changes', ...)
        .subscribe(...);
    // Channel is never unsubscribed
}
```

**Fix Required:**
```javascript
let realtimeChannel = null;

function setupRealtimeSubscription() {
    // Unsubscribe old channel first
    if (realtimeChannel) {
        realtimeChannel.unsubscribe();
    }

    realtimeChannel = db.channel('mmwave_changes')
        .on('postgres_changes', ...)
        .subscribe(...);
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (realtimeChannel) {
        realtimeChannel.unsubscribe();
    }
});
```

---

## 🟡 MODERATE ISSUES

### 7. Race Condition in Mode Detection
**Location:** dashboard.js lines 107-134
**Severity:** MEDIUM
**Impact:** Dashboard may initialize in wrong mode if data loads before mode detection

**Problem:**
```javascript
const detectedMode = await fetchDeviceMode();  // Async
currentMode = detectedMode;
// Meanwhile, other async operations may start with wrong mode
```

**Fix Required:**
Use async/await properly and ensure mode is set before any data loading

---

### 8. No Validation of User Input
**Location:** caretaker_management.js line 68
**Severity:** MEDIUM
**Impact:** Invalid email formats could be sent to database

**Problem:**
```javascript
const email = document.getElementById('caretaker-email').value.trim().toLowerCase();
if (!email || !email.includes('@')) {
    alert('Please enter a valid email address');  // Weak validation
}
```

**Fix Required:**
```javascript
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
if (!emailRegex.test(email)) {
    alert('Please enter a valid email address');
    return;
}
```

---

### 9. Chart Updates Without Null Checks
**Location:** dashboard.js multiple locations
**Severity:** MEDIUM
**Impact:** Crashes if chart objects aren't fully initialized

**Examples:**
```javascript
// dashboard.js:1692
charts.timeline12Hour.update('none');  // No check if chart exists

// dashboard.js:1769
charts.timeline24Hour.update('none');  // No check if chart exists
```

**Some locations do check, others don't - inconsistent**

**Fix Required:**
Consistently check chart existence:
```javascript
if (charts.timeline12Hour) {
    charts.timeline12Hour.update('none');
}
```

---

### 10. Missing CDN Fallbacks
**Location:** index.html lines 7-11
**Severity:** MEDIUM
**Impact:** If CDN is down, entire dashboard fails to load

**Problem:**
```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
```

**Fix Required:**
Add fallback to local copies or alternative CDN:
```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"
        onerror="this.src='/js/chart.min.js'"></script>
```

---

### 11. Sensitive Data in Config File
**Location:** config.js lines 5-9
**Severity:** LOW-MEDIUM
**Impact:** Supabase anon key exposed in client-side code

**Note:** While this is the anonymous key (intended for client use), it's still best practice to:
- Use environment variables
- Implement backend proxy for sensitive operations
- Add rate limiting on the backend

---

## 🟢 MINOR ISSUES

### 12. Console Logs in Production
**Location:** Throughout all JavaScript files
**Severity:** LOW
**Impact:** Performance overhead, security information leakage

**Fix Required:**
- Remove or wrap console.log statements in development check
- Use proper logging library with levels

---

### 13. No Loading States
**Location:** Throughout UI
**Severity:** LOW
**Impact:** Poor user experience when data is loading

**Fix Required:**
Add loading spinners/skeletons for:
- Initial data load
- Chart updates
- Settings saves

---

### 14. No Offline Detection
**Location:** None - feature missing
**Severity:** LOW
**Impact:** Users don't know if they've lost internet connection

**Fix Required:**
```javascript
window.addEventListener('offline', () => {
    document.getElementById('connection-status').textContent = 'No Internet';
    document.querySelector('.status-dot').style.background = '#ef4444';
});

window.addEventListener('online', () => {
    checkDeviceOnlineStatus();
});
```

---

## 📊 SUMMARY

| Severity | Count | Issues |
|----------|-------|--------|
| 🔴 CRITICAL | 6 | Memory leaks, hardcoded IDs, missing error handling |
| 🟡 MODERATE | 5 | Race conditions, weak validation, inconsistent checks |
| 🟢 MINOR | 3 | Console logs, loading states, offline detection |
| **TOTAL** | **14** | |

---

## 🔧 RECOMMENDED IMMEDIATE FIXES (Priority Order)

1. **Fix memory leaks** - Clear intervals properly
2. **Add try-catch around analytics** - Prevent crashes if analytics.js fails
3. **Add retry logic to database queries** - Handle temporary network issues
4. **Clean up realtime subscription** - Prevent orphaned subscriptions
5. **Add device selection UI** - Remove hardcoded device ID
6. **Implement offline detection** - Show user when internet is down
7. **Add CDN fallbacks** - Prevent complete failure if CDN is down
8. **Add loading states** - Improve user experience

---

## 🎯 LONG-TERM IMPROVEMENTS

1. **Implement proper error boundaries** - Catch and display errors gracefully
2. **Add comprehensive logging** - Track errors to external service
3. **Implement service worker** - Enable offline functionality
4. **Add automated testing** - Prevent regressions
5. **Code splitting** - Reduce initial load time
6. **Implement state management** - Redux or similar for better data flow
7. **Add performance monitoring** - Track real user metrics
8. **Implement feature flags** - Gradual rollout of new features

---

## 🐛 POTENTIAL ROOT CAUSES OF DASHBOARD FAILURES

Based on this audit, the most likely causes of repeated dashboard failures are:

1. **Memory leaks from uncleaned intervals** - Dashboard slows down over time until browser crashes
2. **Missing error handling for analytics** - If analytics.js fails to load, entire dashboard crashes
3. **CDN failures** - If jsdelivr.net is down, dashboard won't load
4. **Race conditions in initialization** - Async operations complete in wrong order
5. **Realtime subscription issues** - Orphaned subscriptions cause duplicate events or memory leaks
6. **Network timeouts** - No retry logic means temporary network issues cause permanent failures

**Most Critical Fix:** Implement proper cleanup of intervals and subscriptions to prevent memory leaks.
