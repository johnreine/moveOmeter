# Adding Test moveOmeters with Sample Data

This guide will help you add 3 test moveOmeters to your house with realistic sample data.

## Quick Start

1. **Open Supabase SQL Editor**
   - Go to your Supabase dashboard
   - Navigate to SQL Editor
   - Click "New Query"

2. **Run the Script**
   - Copy the entire contents of `add_test_devices.sql`
   - Paste into the SQL Editor
   - Click "Run" (or press Cmd/Ctrl + Enter)

3. **What Gets Created**
   - **ESP32C6_BEDROOM** - Master Bedroom device
     - High activity: 6-9am and 6-10pm
     - Sleep mode: 12am-6am
     - Low activity: rest of day

   - **ESP32C6_BATHROOM** - Master Bathroom device
     - Burst activity: 7-8am and 8-9pm
     - Minimal activity: rest of day
     - No activity: 12am-6am, 10pm-12am

   - **ESP32C6_KITCHEN** - Kitchen device
     - High activity during meal times: 7-8am, 12-1pm, 6-7pm
     - Moderate activity: between meals
     - Low activity: other times

4. **Sample Data Generated**
   - 7 days of historical sensor data
   - Realistic activity patterns for each room
   - Daily aggregates calculated for all devices
   - All devices attached to your first active house

## Verification

After running the script, check:

```sql
-- View all test devices
SELECT device_id, location_name, device_status, last_seen
FROM moveometers
WHERE device_id LIKE 'ESP32C6_%'
ORDER BY location_name;

-- View data point counts
SELECT device_id, COUNT(*) as readings
FROM mmwave_sensor_data
WHERE device_id LIKE 'ESP32C6_%'
GROUP BY device_id;

-- View daily metrics
SELECT device_id, date, motion_score, total_active_minutes
FROM daily_aggregates
WHERE device_id LIKE 'ESP32C6_%'
ORDER BY device_id, date DESC;
```

## Customization

To modify the script:
- Change device names: Update `v_device_id_1`, `v_device_id_2`, `v_device_id_3` variables
- Change location names: Update `location_name` in INSERT statements
- Adjust activity patterns: Modify the hour ranges in the FOR loops
- Change data retention: Update `v_day_offset IN 0..6` to generate more/fewer days

## Cleanup

To remove test devices:

```sql
-- Delete all test devices and their data
DELETE FROM daily_aggregates WHERE device_id LIKE 'ESP32C6_%';
DELETE FROM mmwave_sensor_data WHERE device_id LIKE 'ESP32C6_%';
DELETE FROM moveometers WHERE device_id LIKE 'ESP32C6_%';
```
