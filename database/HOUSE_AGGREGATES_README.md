# House-Level Daily Aggregates

## Problem

The house summary view in the mobile app was performing **client-side aggregation**:
- Querying all devices in a house (1+ database calls)
- Looping through each of the last 7 days (7 iterations)
- Fetching device-level metrics for each day (7+ database calls)
- Aggregating data in Dart code (summing, averaging, min/max calculations)

This violated the principle: **"NO logic should be in the local viewer"**

## Solution

Migration 15 adds **server-side house-level daily aggregates**:
- House-level metrics are pre-computed and stored in the database
- Mobile app makes simple SELECT queries with zero aggregation logic
- All calculation happens server-side in PostgreSQL

## Changes Made

### Database (Migration 15)

**File**: `database/15_add_house_daily_aggregates.sql`

1. **Added `house_id` column** to `daily_aggregates` table
2. **Created `calculate_house_daily_metrics()`** function that:
   - Aggregates device-level metrics for all devices in a house
   - Stores house-level aggregate with `house_id` set
   - Uses `'HOUSE_' + house_id` as the `device_id` to distinguish house vs device records
3. **Updated `calculate_all_daily_metrics()`** to automatically calculate both:
   - Device-level metrics (existing)
   - House-level metrics (new)
4. **Backfilled last 7 days** of house-level aggregates

### Mobile App (Flutter)

**File**: `pictureFrame/software/moveometer_app/lib/widgets/house_summary_card.dart`

**Before** (Client-side aggregation):
```dart
// Query all devices
final devices = await _supabase.from('moveometers')...

// Query each device's metrics
final todayMetrics = await _supabase.from('daily_aggregates')
  .inFilter('device_id', deviceIds);

// Loop and aggregate in Dart
for (var metric in todayMetrics) {
  totalMotionScore += metric['motion_score'];
  totalActiveMinutes += metric['total_active_minutes'];
  // ... more aggregation logic
}
final avgMotionScore = totalMotionScore / deviceCount;
```

**After** (Server-side query only):
```dart
// Query pre-computed house-level aggregate
final response = await _supabase
  .from('daily_aggregates')
  .select('*')
  .eq('house_id', houseId)
  .eq('date', dateStr)
  .maybeSingle();

// Use server-calculated metrics directly
final motionScore = response['motion_score'];
final activeMinutes = response['total_active_minutes'];
```

**Lines removed**: ~40 lines of aggregation logic

## How to Use

### Run Migration 15

1. Go to **Supabase Dashboard → SQL Editor**
2. Copy contents of `database/15_add_house_daily_aggregates.sql`
3. Click **RUN**
4. Verify success messages in output

The migration will:
- ✅ Add house_id column to daily_aggregates
- ✅ Create house-level calculation functions
- ✅ Backfill last 7 days of house-level data
- ✅ Display verification query results

### Daily Calculation

The `calculate_all_daily_metrics(date)` function now calculates both:
1. **Device-level** metrics (one record per device per day)
2. **House-level** metrics (one record per house per day)

### Manual Calculation

Calculate house metrics for a specific house and date:

```sql
-- Calculate house-level metrics for today
-- Note: house_id is UUID type, cast from string if needed
SELECT calculate_house_daily_metrics('house-uuid-here'::UUID, CURRENT_DATE);

-- Calculate for a specific date
SELECT calculate_house_daily_metrics('house-uuid-here'::UUID, '2026-03-10');
```

### Query House-Level Aggregates

```sql
-- Get today's house-level metrics
SELECT * FROM daily_aggregates
WHERE house_id = 'house-uuid-here'
  AND date = CURRENT_DATE;

-- Get last 7 days
SELECT * FROM daily_aggregates
WHERE house_id = 'house-uuid-here'
  AND date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date DESC;
```

## Architecture

### Data Flow

```
ESP32 → mmwave_sensor_data (raw data)
         ↓
calculate_daily_metrics() → daily_aggregates (device-level)
         ↓
calculate_house_daily_metrics() → daily_aggregates (house-level)
         ↓
Mobile App queries house-level records (NO aggregation)
```

### Database Records

**Device-level record**:
```sql
device_id: 'ESP32C6_001'
house_id: NULL
date: '2026-03-13'
motion_score: 81
total_active_minutes: 252
```

**House-level record**:
```sql
device_id: 'HOUSE_house-uuid'
house_id: 'house-uuid'
date: '2026-03-13'
motion_score: 85  -- Average across all devices
total_active_minutes: 450  -- Sum across all devices
```

## Verification

After running migration 15, verify house-level data exists:

```sql
-- Check house-level aggregates were created
SELECT
  device_id,
  house_id,
  date,
  motion_score,
  total_active_minutes
FROM daily_aggregates
WHERE house_id IS NOT NULL
ORDER BY date DESC;
```

You should see records with:
- ✅ `device_id` starting with `'HOUSE_'`
- ✅ `house_id` populated with house UUID
- ✅ Last 7 days of data

## Benefits

1. **Zero client-side logic** - Mobile app is pure display layer
2. **Single database query** - No more loops or multiple calls
3. **Consistent calculations** - Same logic for all clients (web, mobile, API)
4. **Better performance** - Aggregation happens once server-side, not every time a client loads
5. **Easier debugging** - All logic in SQL, can query and verify directly in database

## Next Steps

- Mobile app will now show house daily history correctly
- Web dashboard could be updated to use house-level aggregates too
- Set up automated daily calculation (pg_cron or scheduled function)
