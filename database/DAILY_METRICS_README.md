# Daily Metrics System

This system calculates daily aggregate metrics from raw sensor data for trend analysis and health monitoring.

## Setup

### 1. Create the daily_aggregates table
Run this in Supabase SQL Editor:
```bash
database/create_daily_aggregates.sql
```

### 2. Create the calculation function
Run this in Supabase SQL Editor:
```bash
database/calculate_daily_metrics_function.sql
```

## Usage

### Calculate metrics for a specific device and date
```sql
SELECT calculate_daily_metrics('ESP32C6_001', '2026-03-05');
```

### Calculate metrics for all devices for a specific date
```sql
SELECT * FROM calculate_all_daily_metrics('2026-03-05');
```

### Calculate yesterday's metrics for all devices
```sql
SELECT * FROM calculate_all_daily_metrics(CURRENT_DATE - INTERVAL '1 day');
```

### View calculated metrics
```sql
SELECT
  date,
  motion_score,
  first_motion_time,
  last_motion_time,
  total_active_minutes,
  movement_sessions,
  fall_count
FROM daily_aggregates
WHERE device_id = 'ESP32C6_001'
ORDER BY date DESC
LIMIT 30;
```

## Metrics Explained

### Motion Score (0-100)
Overall daily activity level calculated from:
- **Active minutes** (up to 50 points) - Total time with movement
- **Movement intensity** (up to 25 points) - How vigorous the movement was
- **Movement sessions** (up to 25 points) - Number of times they got up/moved

Score interpretation:
- **80-100**: Very active day
- **60-79**: Moderately active
- **40-59**: Low activity
- **20-39**: Minimal activity
- **0-19**: Very low activity (concerning)

### Key Metrics

- **first_motion_time** - Wake-up time indicator
- **last_motion_time** - Bedtime indicator
- **total_active_minutes** - Total time with movement detected
- **longest_stationary_minutes** - Longest period sitting/lying still
- **movement_sessions** - How many times they got up and moved
- **average_movement_intensity** - How vigorous movement was when active
- **fall_count** - Number of falls detected

## Trend Analysis

Compare metrics over time:

```sql
-- 7-day motion score trend
SELECT
  date,
  motion_score,
  AVG(motion_score) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as seven_day_avg
FROM daily_aggregates
WHERE device_id = 'ESP32C6_001'
  AND date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY date DESC;
```

```sql
-- Week-over-week comparison
SELECT
  date,
  motion_score,
  LAG(motion_score, 7) OVER (ORDER BY date) as last_week_score,
  motion_score - LAG(motion_score, 7) OVER (ORDER BY date) as weekly_change
FROM daily_aggregates
WHERE device_id = 'ESP32C6_001'
ORDER BY date DESC
LIMIT 14;
```

## Automation

To run calculations automatically at 1 AM UTC every day, enable pg_cron and run:

```sql
SELECT cron.schedule(
  'calculate-daily-metrics',
  '0 1 * * *',
  'SELECT calculate_all_daily_metrics(CURRENT_DATE - INTERVAL ''1 day'');'
);
```

## Next Steps

1. **Run initial backfill** - Calculate metrics for existing historical data
2. **Set up daily automation** - Schedule to run every night
3. **Build dashboard views** - Display metrics in web/mobile app
4. **Add baseline tracking** - Calculate variance_from_baseline_pct
5. **Create alerts** - Notify when scores drop significantly
