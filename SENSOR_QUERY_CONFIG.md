# Sensor Query Configuration

Configure mmWave sensor query timing and data collection patterns remotely through the web UI.

## Overview

The moveOmeter system now allows fine-grained control over how the ESP32-C6 queries the mmWave sensor chip. All settings are configurable through the web dashboard and synced to devices in real-time.

## Database Setup

Run the SQL migration to add sensor query configuration fields:

```bash
psql -h <your-supabase-host> -U postgres -d postgres -f database/add_sensor_query_config.sql
```

Or execute in Supabase SQL Editor:
- Go to Supabase Dashboard → SQL Editor
- Copy contents of `database/add_sensor_query_config.sql`
- Execute

## Configurable Parameters

### 1. Query Delay
- **Field**: `sensor_query_delay_ms`
- **Default**: 0ms (no delay)
- **Range**: 0-500ms
- **Description**: Delay inserted between individual sensor queries within a collection cycle
- **Use Case**: Some mmWave sensors need time to settle between reads. Increase if you see inconsistent readings.

### 2. Query Retry Attempts
- **Field**: `query_retry_attempts`
- **Default**: 1 (no retry)
- **Range**: 1-5 attempts
- **Description**: Number of times to retry a failed sensor query
- **Impact**: Higher values increase reliability but may slow down collection

### 3. Retry Delay
- **Field**: `query_retry_delay_ms`
- **Default**: 100ms
- **Range**: 50-1000ms
- **Description**: Delay between sensor query retry attempts
- **Use Case**: Increase if sensor needs recovery time after errors

### 4. Supplemental Data Collection
- **Field**: `enable_supplemental_queries`
- **Default**: Enabled (true)
- **Type**: Boolean toggle
- **Description**: Enable/disable collection of supplemental sensor data beyond critical metrics
- **Impact**: Disabling reduces sensor query load and speeds up data collection

### 5. Supplemental Query Mode
- **Field**: `supplemental_cycle_mode`
- **Default**: "rotating"
- **Options**:
  - **Rotating**: Cycles through supplemental fields (efficient, default)
  - **All**: Queries all supplemental data every cycle (comprehensive)
  - **None**: Disables supplemental queries entirely (fastest)

## Query Modes Explained

### Rotating Mode (Default)
The device cycles through supplemental queries, collecting one additional field per cycle:

**Fall Detection Mode** (7-cycle rotation):
- Cycle 0: Static residency state
- Cycle 1: Seated horizontal distance
- Cycle 2: Motion horizontal distance
- Cycle 3: Fall break height
- Cycle 4: Fall time
- Cycle 5: Static residency time
- Cycle 6: No supplemental data (critical only)

**Sleep Mode** (10-cycle rotation):
- Cycle 0: Respiration rate
- Cycle 1: Human moving range
- Cycle 2: In/not in bed
- Cycle 3: Sleep state
- Cycle 4: Sleep composite data (5 fields)
- Cycle 5: Sleep statistics (movement)
- Cycle 6: Sleep quality metrics
- Cycle 7: Sleep phase percentages
- Cycle 8: Abnormal struggle
- Cycle 9: Unattended state

### All Mode
Queries all supplemental data every cycle. More comprehensive but:
- Takes longer per collection cycle
- More sensor queries = more power consumption
- May stress the sensor if query delay is low

### None Mode
Only critical data is collected:
- **Fall Detection**: existence, motion, body movement, fall state
- **Sleep Mode**: human presence, heart rate, body movement

Fastest collection, lowest power, but less detailed analytics.

## Web UI Configuration

1. Open the moveOmeter dashboard
2. Expand **⚙️ Device Configuration**
3. Find **🔬 Sensor Query Settings**
4. Adjust the parameters:
   - **Query Delay**: Slider (0-500ms)
   - **Query Retry Attempts**: Slider (1-5)
   - **Retry Delay**: Slider (50-1000ms)
   - **Supplemental Data Collection**: Toggle on/off
   - **Supplemental Query Mode**: Dropdown (Rotating/All/None)
5. Click **💾 Save Settings to Device**

## Performance Impact

### Query Delay
| Delay | Collection Time (Rotating) | Collection Time (All) |
|-------|---------------------------|-----------------------|
| 0ms | ~50-100ms | ~200-300ms |
| 50ms | ~250-350ms | ~800-1000ms |
| 100ms | ~500-600ms | ~1500-2000ms |

### Supplemental Mode
| Mode | Queries/Cycle | Time/Cycle | Data Completeness |
|------|---------------|------------|------------------|
| Rotating | 4-5 | Fast | Delayed (7-10 cycles for full dataset) |
| All | 10-15 | Slow | Immediate (every cycle) |
| None | 3-4 | Fastest | Critical only |

## Tuning Guidelines

### For Stable Sensors (DFRobot SEN0623)
```
Query Delay: 0ms
Retry Attempts: 1
Retry Delay: 100ms
Supplemental Mode: Rotating
```
Fast, efficient, no delays needed.

### For Unreliable Connections
```
Query Delay: 50ms
Retry Attempts: 3
Retry Delay: 200ms
Supplemental Mode: Rotating
```
More robust against intermittent failures.

### For Maximum Data Density
```
Query Delay: 0ms
Retry Attempts: 1
Supplemental Mode: All
```
Collect all data every cycle (warning: slower).

### For Battery Conservation
```
Query Delay: 0ms
Retry Attempts: 1
Supplemental Mode: None
```
Critical data only, fastest collection.

### For Debugging Sensor Issues
```
Query Delay: 100ms
Retry Attempts: 5
Retry Delay: 500ms
Supplemental Mode: Rotating
```
Maximum tolerance for sensor issues.

## Real-World Examples

### Example 1: Standard Home Monitoring
```sql
UPDATE moveometers
SET sensor_query_delay_ms = 0,
    query_retry_attempts = 1,
    query_retry_delay_ms = 100,
    enable_supplemental_queries = true,
    supplemental_cycle_mode = 'rotating'
WHERE device_id = 'ESP32C6_001';
```
**Result**: Efficient, balanced monitoring with all data over time.

### Example 2: Critical Care (Hospital)
```sql
UPDATE moveometers
SET sensor_query_delay_ms = 0,
    query_retry_attempts = 2,
    supplemental_cycle_mode = 'all',
    fall_detection_interval_ms = 5000
WHERE device_id = 'ESP32C6_HOSPITAL_01';
```
**Result**: Maximum data density, faster sampling, highly reliable.

### Example 3: Battery-Powered Remote Cabin
```sql
UPDATE moveometers
SET sensor_query_delay_ms = 0,
    query_retry_attempts = 1,
    supplemental_cycle_mode = 'none',
    fall_detection_interval_ms = 60000
WHERE device_id = 'ESP32C6_CABIN_01';
```
**Result**: Minimal power usage, basic monitoring.

### Example 4: Troubleshooting Sensor
```sql
UPDATE moveometers
SET sensor_query_delay_ms = 200,
    query_retry_attempts = 5,
    query_retry_delay_ms = 500,
    enable_supplemental_queries = false
WHERE device_id = 'ESP32C6_DEBUG';
```
**Result**: Maximum tolerance, easier to diagnose issues.

## How It Works

### Data Collection Flow

```
1. Device timer triggers data collection
2. Query critical sensors (with delays if configured)
3. Check supplemental mode setting:
   - If "none": Skip to step 5
   - If "all": Query all supplemental sensors
   - If "rotating": Query one supplemental field
4. Build JSON payload
5. Upload to Supabase
6. Increment rotation index (rotating mode only)
```

### Query Delay Application

```cpp
// Critical data
uint16_t existence = sensor.dmHumanData(eExistence);
if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);

uint16_t motion = sensor.dmHumanData(eMotion);
if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);
// ... etc
```

Each query waits for the configured delay before the next query.

## Monitoring Query Performance

Check device logs via serial monitor:

```
[QUICK+SUPP0] Reading...
--- JSON DATA ---
{"device_id":"ESP32C6_001",...}
-----------------
Read: 45ms, Upload: 234ms, Total: 279ms
```

- **Read time** increases with query delay and retry attempts
- **All mode** shows significantly longer read times
- Use this to tune delay values

## Troubleshooting

### Inconsistent Sensor Readings
**Solution**: Increase `sensor_query_delay_ms` to 50-100ms

### Sensor Timeouts
**Solution**: Increase `query_retry_attempts` to 2-3 and `query_retry_delay_ms` to 200-500ms

### Slow Data Collection
**Solution**:
- Reduce `sensor_query_delay_ms` to 0
- Set `supplemental_cycle_mode` to "rotating" or "none"
- Reduce `query_retry_attempts` to 1

### Missing Supplemental Data
**Solution**:
- Ensure `enable_supplemental_queries` is true
- Set `supplemental_cycle_mode` to "all" for immediate data
- In rotating mode, wait 7-10 cycles for complete dataset

### High Battery Drain
**Solution**:
- Set `supplemental_cycle_mode` to "none"
- Reduce query delays to 0
- Increase sampling intervals (see SAMPLING_RATE_CONFIG.md)

## Advanced Configuration

### Per-Sensor Tuning
Different sensor models may need different settings:

```sql
-- SEN0623 (stable, fast)
UPDATE moveometers
SET sensor_query_delay_ms = 0,
    supplemental_cycle_mode = 'rotating'
WHERE sensor_model = 'SEN0623';

-- SEN0610 (needs settling time)
UPDATE moveometers
SET sensor_query_delay_ms = 100,
    supplemental_cycle_mode = 'rotating'
WHERE sensor_model = 'SEN0610';
```

### Time-Based Profiles
Use database triggers to adjust settings based on time of day:

```sql
-- Night mode: less data, more battery
-- Day mode: full monitoring
```

## Best Practices

1. **Start with defaults**: Rotating mode, 0ms delay, 1 retry
2. **Monitor performance**: Check serial logs for query times
3. **Tune incrementally**: Change one parameter at a time
4. **Test thoroughly**: Verify data quality after changes
5. **Document changes**: Note why settings were changed

## Future Enhancements

Potential additions:
- Adaptive query delay based on sensor response time
- Per-field query enable/disable (granular control)
- Query timing histograms for optimization
- Automatic retry escalation on persistent failures
