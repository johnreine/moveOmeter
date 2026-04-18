# Critical Fixes Implementation Guide

## Fix #1: Memory Leaks from Uncleaned Intervals

### dashboard.js - Add at the top of the file after variable declarations:

```javascript
// Interval and subscription cleanup
let refreshIntervalId = null;
let timelineIntervalId = null;
let statusIntervalId = null;
let realtimeChannel = null;

// Cleanup function
function cleanupDashboard() {
    console.log('🧹 Cleaning up dashboard resources...');

    // Clear all intervals
    if (refreshIntervalId) {
        clearInterval(refreshIntervalId);
        refreshIntervalId = null;
    }
    if (timelineIntervalId) {
        clearInterval(timelineIntervalId);
        timelineIntervalId = null;
    }
    if (statusIntervalId) {
        clearInterval(statusIntervalId);
        statusIntervalId = null;
    }

    // Unsubscribe from realtime
    if (realtimeChannel) {
        realtimeChannel.unsubscribe();
        realtimeChannel = null;
    }

    console.log('✅ Dashboard cleanup complete');
}

// Add cleanup on page unload
window.addEventListener('beforeunload', cleanupDashboard);

// Also cleanup when user logs out (to prevent leaks during same session)
window.addEventListener('dashboardDestroy', cleanupDashboard);
```

### dashboard.js - Update initialization code (around line 158):

**REPLACE:**
```javascript
// Set up periodic refresh as backup
setInterval(loadLatestData, DASHBOARD_CONFIG.refreshInterval);

// Refresh timeline charts every 2 minutes to ensure current data
setInterval(async () => {
    console.log('🔄 Auto-refreshing timeline charts...');
    await load12HourData();
    await load24HourData();
}, 2 * 60 * 1000); // Every 2 minutes

// Check device online status every 2 seconds
setInterval(checkDeviceOnlineStatus, 2000);
```

**WITH:**
```javascript
// Clean up old intervals before creating new ones
cleanupDashboard();

// Set up periodic refresh as backup
refreshIntervalId = setInterval(loadLatestData, DASHBOARD_CONFIG.refreshInterval);

// Refresh timeline charts every 2 minutes to ensure current data
timelineIntervalId = setInterval(async () => {
    console.log('🔄 Auto-refreshing timeline charts...');
    await load12HourData();
    await load24HourData();
}, 2 * 60 * 1000); // Every 2 minutes

// Check device online status every 2 seconds
statusIntervalId = setInterval(checkDeviceOnlineStatus, 2000);

console.log('✅ Dashboard intervals initialized');
```

### dashboard.js - Update setupRealtimeSubscription function:

**REPLACE:**
```javascript
function setupRealtimeSubscription() {
    const channel = db
        .channel('mmwave_changes')
        .on(
            'postgres_changes',
            {
                event: 'INSERT',
                schema: 'public',
                table: SUPABASE_CONFIG.table,
                filter: DASHBOARD_CONFIG.deviceId ? `device_id=eq.${DASHBOARD_CONFIG.deviceId}` : undefined
            },
            (payload) => {
                console.log('New data received:', payload.new);
                addNewDataPoint(payload.new);
            }
        )
        .subscribe((status) => {
            console.log('Realtime subscription status:', status);
            updateConnectionStatus(status === 'SUBSCRIBED');
        });
}
```

**WITH:**
```javascript
function setupRealtimeSubscription() {
    // Unsubscribe from old channel if exists
    if (realtimeChannel) {
        console.log('🧹 Cleaning up old realtime subscription');
        realtimeChannel.unsubscribe();
        realtimeChannel = null;
    }

    realtimeChannel = db
        .channel('mmwave_changes')
        .on(
            'postgres_changes',
            {
                event: 'INSERT',
                schema: 'public',
                table: SUPABASE_CONFIG.table,
                filter: DASHBOARD_CONFIG.deviceId ? `device_id=eq.${DASHBOARD_CONFIG.deviceId}` : undefined
            },
            (payload) => {
                console.log('New data received:', payload.new);
                addNewDataPoint(payload.new);
            }
        )
        .subscribe((status) => {
            console.log('Realtime subscription status:', status);
            updateConnectionStatus(status === 'SUBSCRIBED');
        });

    console.log('✅ Realtime subscription initialized');
}
```

---

## Fix #2: Analytics Error Handling

### analytics.js - Update initializeAnalytics function:

**REPLACE:**
```javascript
// Initialize analytics after user logs in
function initializeAnalytics(supabaseClient, userId) {
    analytics = new AnalyticsService(supabaseClient);
    analytics.initSession(userId);

    // Update metrics every 30 seconds
    setInterval(() => {
        if (analytics) {
            analytics.updateSessionMetrics();
        }
    }, 30000);
}
```

**WITH:**
```javascript
// Analytics interval ID
let analyticsIntervalId = null;

// Cleanup analytics
function cleanupAnalytics() {
    if (analyticsIntervalId) {
        clearInterval(analyticsIntervalId);
        analyticsIntervalId = null;
    }
    if (analytics) {
        analytics.endSession().catch(err => {
            console.error('Error ending analytics session:', err);
        });
        analytics = null;
    }
}

// Initialize analytics after user logs in
function initializeAnalytics(supabaseClient, userId) {
    try {
        // Clean up old analytics first
        cleanupAnalytics();

        analytics = new AnalyticsService(supabaseClient);
        analytics.initSession(userId);

        // Update metrics every 30 seconds
        analyticsIntervalId = setInterval(() => {
            if (analytics) {
                analytics.updateSessionMetrics().catch(err => {
                    console.error('Error updating analytics metrics:', err);
                });
            }
        }, 30000);

        console.log('✅ Analytics initialized');
    } catch (err) {
        console.error('❌ Analytics initialization failed:', err);
        // Continue without analytics - don't crash the app
        analytics = null;
    }
}

// Cleanup on page unload
window.addEventListener('beforeunload', cleanupAnalytics);
```

### analytics.js - Make trackAction safer:

**REPLACE:**
```javascript
// Helper function to track action (can be called from anywhere)
function trackAction(actionType, actionCategory, actionTarget, actionValue = null) {
    if (analytics) {
        analytics.trackAction(actionType, actionCategory, actionTarget, actionValue);
    }
}
```

**WITH:**
```javascript
// Helper function to track action (can be called from anywhere)
function trackAction(actionType, actionCategory, actionTarget, actionValue = null) {
    try {
        if (analytics) {
            analytics.trackAction(actionType, actionCategory, actionTarget, actionValue);
        }
    } catch (err) {
        console.error('Analytics tracking failed:', err);
        // Don't crash the app if analytics fails
    }
}
```

### auth-guard.js - Wrap analytics initialization:

**REPLACE:**
```javascript
// Initialize analytics tracking
initializeAnalytics(authClient, session.user.id);
```

**WITH:**
```javascript
// Initialize analytics tracking
try {
    if (typeof initializeAnalytics === 'function') {
        initializeAnalytics(authClient, session.user.id);
    }
} catch (err) {
    console.error('❌ Analytics initialization failed:', err);
    // Continue without analytics - don't crash the app
}
```

**REPLACE:**
```javascript
if (confirm('Are you sure you want to sign out?')) {
    // End analytics session before logout
    if (analytics) {
        await analytics.endSession();
    }
    await authClient.auth.signOut();
    window.location.href = 'login.html';
}
```

**WITH:**
```javascript
if (confirm('Are you sure you want to sign out?')) {
    // End analytics session before logout
    try {
        if (typeof cleanupAnalytics === 'function') {
            cleanupAnalytics();
        } else if (analytics) {
            await analytics.endSession();
        }
    } catch (err) {
        console.error('Error ending analytics session:', err);
    }

    await authClient.auth.signOut();
    window.location.href = 'login.html';
}
```

---

## Fix #3: Database Query Retry Logic

### Add to dashboard.js (near the top, after imports):

```javascript
// Database query with retry logic
async function queryWithRetry(queryFn, maxRetries = 3, operation = 'database query') {
    for (let attempt = 0; attempt < maxRetries; attempt++) {
        try {
            const result = await queryFn();

            if (result.error) {
                // Check if error is retryable
                const isRetryable =
                    result.error.message?.includes('network') ||
                    result.error.message?.includes('timeout') ||
                    result.error.message?.includes('connection') ||
                    result.error.code === 'PGRST301'; // Supabase timeout

                if (!isRetryable || attempt === maxRetries - 1) {
                    throw result.error;
                }

                const delay = 1000 * Math.pow(2, attempt); // Exponential backoff
                console.warn(`⚠️ ${operation} failed (attempt ${attempt + 1}/${maxRetries}), retrying in ${delay}ms...`, result.error);
                await new Promise(resolve => setTimeout(resolve, delay));
                continue;
            }

            // Success
            if (attempt > 0) {
                console.log(`✅ ${operation} succeeded after ${attempt + 1} attempts`);
            }
            return result;

        } catch (err) {
            const isRetryable =
                err.message?.includes('network') ||
                err.message?.includes('timeout') ||
                err.message?.includes('Failed to fetch');

            if (!isRetryable || attempt === maxRetries - 1) {
                throw err;
            }

            const delay = 1000 * Math.pow(2, attempt);
            console.warn(`⚠️ ${operation} failed (attempt ${attempt + 1}/${maxRetries}), retrying in ${delay}ms...`, err);
            await new Promise(resolve => setTimeout(resolve, delay));
        }
    }
}
```

### Example usage - Update load12HourData function:

**REPLACE:**
```javascript
const { data: batch, error: batchError } = await query;

if (batchError) {
    console.error('❌ Batch query error:', batchError);
    throw batchError;
}
```

**WITH:**
```javascript
const result = await queryWithRetry(
    () => query,
    3,
    `Loading 12-hour data batch ${Math.floor(offset / batchSize) + 1}`
);

if (result.error) {
    console.error('❌ Batch query error:', result.error);
    throw result.error;
}

const batch = result.data;
```

---

## Fix #4: Offline Detection

### Add to index.html before closing </body> tag:

```html
<script>
// Offline/Online detection
window.addEventListener('offline', () => {
    console.warn('🔴 Internet connection lost');
    const statusElement = document.getElementById('connection-status');
    const dotElement = document.querySelector('.status-dot');
    if (statusElement) {
        statusElement.textContent = 'No Internet Connection';
        statusElement.style.color = '#ef4444';
        statusElement.style.fontWeight = 'bold';
    }
    if (dotElement) {
        dotElement.style.background = '#ef4444';
        dotElement.style.animation = 'none';
    }
});

window.addEventListener('online', () => {
    console.log('✅ Internet connection restored');
    const statusElement = document.getElementById('connection-status');
    const dotElement = document.querySelector('.status-dot');
    if (statusElement) {
        statusElement.textContent = 'Reconnecting...';
        statusElement.style.color = '#f59e0b';
        statusElement.style.fontWeight = 'normal';
    }
    if (dotElement) {
        dotElement.style.background = '#f59e0b';
    }

    // Recheck device status
    if (typeof checkDeviceOnlineStatus === 'function') {
        setTimeout(checkDeviceOnlineStatus, 1000);
    }
});
</script>
```

---

## Fix #5: CDN Fallbacks

### Update index.html - Add error handlers to CDN scripts:

**REPLACE:**
```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns"></script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation@3.0.1/dist/chartjs-plugin-annotation.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-zoom@2.0.1/dist/chartjs-plugin-zoom.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

**WITH:**
```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"
        onerror="console.error('Failed to load Chart.js from CDN'); alert('Failed to load charting library. Please refresh the page.');">
</script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns"
        onerror="console.error('Failed to load chartjs-adapter-date-fns from CDN');">
</script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation@3.0.1/dist/chartjs-plugin-annotation.min.js"
        onerror="console.warn('Failed to load chartjs-plugin-annotation from CDN - annotations will be disabled');">
</script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-zoom@2.0.1/dist/chartjs-plugin-zoom.min.js"
        onerror="console.warn('Failed to load chartjs-plugin-zoom from CDN - zoom will be disabled');">
</script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"
        onerror="console.error('Failed to load Supabase from CDN'); alert('Failed to load database library. Please refresh the page.');">
</script>
```

---

## Fix #6: Chart Annotation Safety Checks

### Add to dashboard.js - Create safe annotation helper:

```javascript
// Safely add annotation to chart (checks if plugin is available)
function safeAddAnnotation(chart, annotationKey, annotationConfig) {
    if (!chart || !chart.options) {
        console.warn('Chart not initialized, cannot add annotation');
        return false;
    }

    // Check if annotation plugin is available
    if (typeof Chart === 'undefined' || !Chart.registry.plugins.get('annotation')) {
        console.warn('Chart.js annotation plugin not available');
        return false;
    }

    try {
        if (!chart.options.plugins) {
            chart.options.plugins = {};
        }
        if (!chart.options.plugins.annotation) {
            chart.options.plugins.annotation = { annotations: {} };
        }

        chart.options.plugins.annotation.annotations[annotationKey] = annotationConfig;
        return true;
    } catch (err) {
        console.error('Error adding annotation:', err);
        return false;
    }
}

// Safely remove annotation from chart
function safeRemoveAnnotation(chart, annotationKey) {
    if (!chart || !chart.options || !chart.options.plugins || !chart.options.plugins.annotation) {
        return false;
    }

    try {
        delete chart.options.plugins.annotation.annotations[annotationKey];
        return true;
    } catch (err) {
        console.error('Error removing annotation:', err);
        return false;
    }
}
```

### Update addOfflineAnnotation function to use safe helpers:

**REPLACE:**
```javascript
chart.options.plugins.annotation.annotations.offlineBox = { ... };
chart.options.plugins.annotation.annotations.offlineLine = { ... };
```

**WITH:**
```javascript
safeAddAnnotation(chart, 'offlineBox', { ... });
safeAddAnnotation(chart, 'offlineLine', { ... });

// And for removing:
safeRemoveAnnotation(chart, 'offlineBox');
safeRemoveAnnotation(chart, 'offlineLine');
```

---

## TESTING CHECKLIST

After implementing these fixes, test:

- [ ] Open dashboard, wait 10 minutes, check browser memory usage (should be stable)
- [ ] Refresh page multiple times rapidly (should not accumulate intervals)
- [ ] Navigate away and back (should cleanup properly)
- [ ] Disconnect internet (should show offline message)
- [ ] Block analytics.js from loading (dashboard should still work)
- [ ] Block Chart.js CDN (should show error message)
- [ ] Simulate slow network (queries should retry and succeed)
- [ ] Open browser console and check for error messages
- [ ] Leave dashboard open overnight (should not crash or slow down)

---

## DEPLOYMENT ORDER

1. Deploy analytics.js fixes first (safest, least impact)
2. Deploy dashboard.js fixes (most critical)
3. Deploy auth-guard.js fixes
4. Deploy index.html fixes (CDN fallbacks and offline detection)
5. Monitor for 24 hours
6. Check server logs for errors
7. Verify memory usage doesn't grow over time
