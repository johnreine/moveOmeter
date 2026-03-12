# Daily Metrics Mobile App Implementation

## Overview

Updated the Flutter mobile app to display daily metrics from the new `daily_aggregates` database table.

## Changes Made

### 1. Database Setup

Added two new metric columns to the `daily_aggregates` table:
- **offline_minutes**: Minutes during the day with no data
- **peak_activity_hour**: Hour (0-23) with the most movement activity

Run these SQL commands to add the columns:
```sql
-- File: database/add_new_metrics_columns.sql
ALTER TABLE daily_aggregates
  ADD COLUMN IF NOT EXISTS offline_minutes INTEGER,
  ADD COLUMN IF NOT EXISTS peak_activity_hour INTEGER CHECK (peak_activity_hour >= 0 AND peak_activity_hour <= 23);
```

### 2. Flutter Service Updates

**File: `lib/services/sensor_data_service.dart`**

Added new `DailyMetrics` model class to represent daily aggregate data:
- Date, motion score, wake/sleep times
- Active minutes, movement sessions
- Offline time, peak activity hour
- Fall count, data coverage percentage

Added three new service methods:
- `fetchDailyMetrics(deviceId, days: 7)` - Fetch past N days of metrics
- `fetchTodayMetrics(deviceId)` - Fetch today's metrics (may be incomplete)
- `fetch24HourData(deviceId, date)` - Fetch full 24-hour timeline for a specific date

### 3. New Page: Day Detail View

**File: `lib/pages/day_detail_page.dart`**

New page that shows:
- **Daily Metrics Card**: Motion score, wake/sleep times, activity stats, falls, data coverage
- **24-Hour Activity Graph**: Full day timeline with presence and movement data

The page adapts for "today" vs past days, showing "IN PROGRESS" badge for today's metrics.

### 4. Updated Device Detail Page

**File: `lib/pages/device_detail_page.dart`**

Restructured page layout (top to bottom):

1. **Last Hour Section** (existing) - Real-time data, online/offline status
2. **Today's Activity Section** (NEW) - Current day metrics so far:
   - Large motion score display
   - Quick stats tiles (active minutes, sessions, wake/last motion)
   - "IN PROGRESS" badge
3. **Past 7 Days Section** (NEW) - List of last 7 days:
   - Each day is a clickable card
   - Shows motion score badge and quick stats
   - Taps navigate to Day Detail Page for 24-hour view
4. **Daily History Section** (existing, hidden) - Old hourly bar charts

## User Experience Flow

1. User opens moveometer page → sees real-time hourly data at top
2. Scrolls down → sees today's metrics updating throughout the day
3. Scrolls down → sees past 7 days as a list
4. Taps any day → navigates to detailed view with 24-hour graph and full metrics
5. Can swipe back to return to main page

## Motion Score Color Coding

- **Green (70-100)**: Very Active
- **Orange (40-69)**: Moderate Activity
- **Red (0-39)**: Low Activity

## Next Steps

### To Deploy:

1. **Update the database:**
   ```sql
   -- Add new columns
   ALTER TABLE daily_aggregates
     ADD COLUMN IF NOT EXISTS offline_minutes INTEGER,
     ADD COLUMN IF NOT EXISTS peak_activity_hour INTEGER;

   -- Update the calculate_daily_metrics function
   -- Run the entire updated file: database/calculate_daily_metrics_function.sql
   ```

2. **Recalculate existing metrics** to populate new columns:
   ```sql
   SELECT calculate_daily_metrics('ESP32C6_001', '2026-03-04');
   SELECT calculate_daily_metrics('ESP32C6_001', '2026-03-03');
   -- etc for past 7 days
   ```

3. **Build and deploy the mobile app:**
   ```bash
   cd pictureFrame/software/moveometer_app
   flutter build apk  # For Android
   flutter build ios  # For iOS
   ```

### Future Enhancements:

- Add weekly/monthly trend charts
- Show baseline comparison ("10% above your average")
- Add notifications for significant changes
- Export daily reports as PDF
- Add date picker to view any historical day
- Show comparison between multiple days

## Files Modified

- `database/add_new_metrics_columns.sql` (NEW)
- `database/calculate_daily_metrics_function.sql` (UPDATED)
- `lib/services/sensor_data_service.dart` (UPDATED)
- `lib/pages/day_detail_page.dart` (NEW)
- `lib/pages/device_detail_page.dart` (UPDATED)

## Testing Checklist

- [ ] Add new columns to database
- [ ] Update calculate_daily_metrics function
- [ ] Recalculate metrics for past 7 days
- [ ] Build Flutter app without errors
- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Verify today's metrics update in real-time
- [ ] Verify past days list shows correctly
- [ ] Verify tapping a day opens detail view
- [ ] Verify 24-hour graph displays correctly
- [ ] Verify motion score colors are correct
