# Server-Side Architecture Plan
## Moving All Logic from Clients to Database

**Problem:** Clients (web dashboard and mobile app) are currently doing extensive data processing, status calculations, and business logic. This causes inconsistencies, bugs, and violates the principle that clients should just display data.

**Goal:** Move ALL logic to the server. Clients become read-only displays of pre-computed database values.

---

## Phase 1: Device Status Tracking

### 1.1 Database Schema Changes

**Add columns to `moveometers` table:**
```sql
ALTER TABLE moveometers ADD COLUMN IF NOT EXISTS
    connection_status VARCHAR(20) DEFAULT 'unknown', -- 'online', 'stale', 'offline', 'unknown'
    connection_status_updated_at TIMESTAMPTZ,
    seconds_since_last_data INTEGER,
    connection_quality_score INTEGER DEFAULT 0, -- 0-100
    last_data_received_at TIMESTAMPTZ; -- Auto-updated on each data insert
```

**Create device status history table:**
```sql
CREATE TABLE IF NOT EXISTS device_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT REFERENCES moveometers(device_id),
    status VARCHAR(20) NOT NULL, -- 'online', 'stale', 'offline'
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_device_status_history_device ON device_status_history(device_id, started_at DESC);
```

### 1.2 Database Function: Update Device Status

**Function runs on every data insert via trigger:**
```sql
CREATE OR REPLACE FUNCTION update_device_status()
RETURNS TRIGGER AS $$
DECLARE
    v_seconds_since_last INTEGER;
    v_new_status VARCHAR(20);
    v_old_status VARCHAR(20);
BEGIN
    -- Calculate seconds since last data
    v_seconds_since_last := EXTRACT(EPOCH FROM (NOW() - COALESCE(NEW.device_timestamp, NEW.created_at)));

    -- Determine new status based on thresholds
    IF v_seconds_since_last <= 20 THEN
        v_new_status := 'online';
    ELSIF v_seconds_since_last <= 60 THEN
        v_new_status := 'stale';
    ELSE
        v_new_status := 'offline';
    END IF;

    -- Get current status
    SELECT connection_status INTO v_old_status
    FROM moveometers
    WHERE device_id = NEW.device_id;

    -- Update device status
    UPDATE moveometers SET
        connection_status = v_new_status,
        connection_status_updated_at = NOW(),
        seconds_since_last_data = v_seconds_since_last,
        last_data_received_at = COALESCE(NEW.device_timestamp, NEW.created_at),
        connection_quality_score = CASE
            WHEN v_seconds_since_last <= 20 THEN 100
            WHEN v_seconds_since_last <= 60 THEN 70
            ELSE 0
        END
    WHERE device_id = NEW.device_id;

    -- Record status change in history
    IF v_old_status IS DISTINCT FROM v_new_status THEN
        -- End previous status period
        UPDATE device_status_history
        SET ended_at = NOW(),
            duration_seconds = EXTRACT(EPOCH FROM (NOW() - started_at))
        WHERE device_id = NEW.device_id
            AND ended_at IS NULL;

        -- Start new status period
        INSERT INTO device_status_history (device_id, status, started_at)
        VALUES (NEW.device_id, v_new_status, NOW());
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to sensor data inserts
CREATE TRIGGER trigger_update_device_status
    AFTER INSERT ON mmwave_sensor_data
    FOR EACH ROW
    EXECUTE FUNCTION update_device_status();
```

### 1.3 Scheduled Job: Check for Stale Devices

**Runs every 30 seconds to update devices that haven't sent data:**
```sql
CREATE OR REPLACE FUNCTION check_stale_devices()
RETURNS void AS $$
DECLARE
    v_device RECORD;
    v_seconds_since_last INTEGER;
    v_new_status VARCHAR(20);
BEGIN
    FOR v_device IN
        SELECT device_id, connection_status, last_data_received_at
        FROM moveometers
        WHERE device_status = 'active'
    LOOP
        v_seconds_since_last := EXTRACT(EPOCH FROM (NOW() - v_device.last_data_received_at));

        IF v_seconds_since_last <= 20 THEN
            v_new_status := 'online';
        ELSIF v_seconds_since_last <= 60 THEN
            v_new_status := 'stale';
        ELSE
            v_new_status := 'offline';
        END IF;

        -- Only update if status changed
        IF v_device.connection_status IS DISTINCT FROM v_new_status THEN
            UPDATE moveometers SET
                connection_status = v_new_status,
                connection_status_updated_at = NOW(),
                seconds_since_last_data = v_seconds_since_last
            WHERE device_id = v_device.device_id;

            -- Update history
            UPDATE device_status_history
            SET ended_at = NOW(),
                duration_seconds = EXTRACT(EPOCH FROM (NOW() - started_at))
            WHERE device_id = v_device.device_id
                AND ended_at IS NULL;

            INSERT INTO device_status_history (device_id, status, started_at)
            VALUES (v_device.device_id, v_new_status, NOW());
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Schedule via pg_cron or Supabase scheduled function (runs every 30 seconds)
SELECT cron.schedule(
    'check-stale-devices',
    '*/30 * * * * *', -- Every 30 seconds
    'SELECT check_stale_devices();'
);
```

---

## Phase 2: Pre-compute Offline Periods

### 2.1 Create Offline Periods View

**Materialized view or table with offline periods:**
```sql
CREATE TABLE IF NOT EXISTS device_offline_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT REFERENCES moveometers(device_id),
    offline_start TIMESTAMPTZ NOT NULL,
    offline_end TIMESTAMPTZ,
    duration_seconds INTEGER,
    is_ongoing BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_offline_periods_device ON device_offline_periods(device_id, offline_start DESC);
```

### 2.2 Function to Track Offline Periods

**Auto-populated from device_status_history:**
```sql
CREATE OR REPLACE FUNCTION sync_offline_periods()
RETURNS void AS $$
BEGIN
    -- Close ongoing offline periods that have ended
    UPDATE device_offline_periods
    SET offline_end = h.ended_at,
        duration_seconds = h.duration_seconds,
        is_ongoing = false
    FROM device_status_history h
    WHERE device_offline_periods.device_id = h.device_id
        AND device_offline_periods.is_ongoing = true
        AND h.status IN ('stale', 'offline')
        AND h.ended_at IS NOT NULL;

    -- Create new offline periods from history
    INSERT INTO device_offline_periods (device_id, offline_start, offline_end, duration_seconds, is_ongoing)
    SELECT
        device_id,
        started_at,
        ended_at,
        duration_seconds,
        ended_at IS NULL
    FROM device_status_history
    WHERE status IN ('stale', 'offline')
        AND NOT EXISTS (
            SELECT 1 FROM device_offline_periods
            WHERE device_offline_periods.device_id = device_status_history.device_id
                AND device_offline_periods.offline_start = device_status_history.started_at
        );
END;
$$ LANGUAGE plpgsql;
```

---

## Phase 3: Client-Side Simplification

### 3.1 Mobile App Changes

**Remove from app:**
- `_deviceOnlineStatus` getter - DELETE
- Gap detection logic (lines 404-485) - DELETE
- Offline period calculation - DELETE
- All threshold constants (65s, etc.) - DELETE

**Replace with:**
```dart
// Just read from database
final device = await _supabase
    .from('moveometers')
    .select('connection_status, seconds_since_last_data, connection_quality_score')
    .eq('device_id', deviceId)
    .single();

// Display the status
final status = device['connection_status']; // 'online', 'stale', 'offline'
final secondsAgo = device['seconds_since_last_data'];
final quality = device['connection_quality_score'];
```

**For offline periods in charts:**
```dart
// Query pre-computed offline periods
final offlinePeriods = await _supabase
    .from('device_offline_periods')
    .select('offline_start, offline_end')
    .eq('device_id', deviceId)
    .gte('offline_start', oneHourAgo.toIso8601String())
    .order('offline_start');

// Just display them - no calculation needed
```

### 3.2 Web Dashboard Changes

**Remove from dashboard.js:**
- `checkDeviceOnlineStatus()` function - DELETE
- All threshold constants - DELETE
- Gap detection in charts - DELETE
- Device status calculation (lines 1580-1609) - DELETE

**Replace with:**
```javascript
// Just read from database
const { data: device } = await db
    .from('moveometers')
    .select('connection_status, seconds_since_last_data, connection_quality_score')
    .eq('device_id', deviceId)
    .single();

// Update UI
updateStatusDisplay(device.connection_status, device.seconds_since_last_data);
```

---

## Phase 4: Migration Steps

### Step 1: Database Setup
1. Run schema migrations (add columns, create tables)
2. Create functions and triggers
3. Set up scheduled job for stale device checking
4. Backfill initial status for existing devices

### Step 2: Test Server-Side Logic
1. Insert test data and verify status updates correctly
2. Check that status history is being recorded
3. Verify scheduled job runs and updates stale devices
4. Validate offline periods are computed correctly

### Step 3: Update Clients (Mobile App)
1. Remove all status calculation logic
2. Update queries to read status from database
3. Remove gap detection and offline period calculation
4. Test thoroughly
5. Deploy

### Step 4: Update Clients (Web Dashboard)
1. Remove all status calculation logic
2. Update to read from database
3. Remove chart gap detection
4. Test thoroughly
5. Deploy

### Step 5: Cleanup
1. Remove unused functions from client code
2. Remove unused constants and thresholds
3. Update documentation
4. Monitor for issues

---

## Success Criteria

✅ Device status (online/stale/offline) is calculated server-side
✅ Status updates within 30 seconds of data changes
✅ Status history is recorded for analytics
✅ Offline periods are pre-computed
✅ Mobile app contains ZERO status calculation logic
✅ Web dashboard contains ZERO status calculation logic
✅ Clients only read and display database values
✅ Consistent status shown across web and mobile
✅ No timestamp comparison on client side
✅ No threshold constants in client code

---

## Benefits

1. **Single Source of Truth** - Status calculated once, in one place
2. **Consistency** - Web and mobile always show same status
3. **Performance** - Clients don't do calculations
4. **Maintainability** - Change thresholds in one place
5. **Scalability** - Server-side logic scales better
6. **Reliability** - Database triggers ensure accurate status
7. **Debuggability** - Status history table for troubleshooting
8. **Simplicity** - Clients become dumb displays

---

## Timeline

- Phase 1 (Device Status): 2-3 hours
- Phase 2 (Offline Periods): 1-2 hours
- Phase 3 (Client Updates): 2-3 hours
- Phase 4 (Testing & Deploy): 1-2 hours

**Total: ~8-10 hours of work**

---

## Next Steps

1. Review and approve this plan
2. Create database migration scripts
3. Implement and test server-side functions
4. Update clients to use new architecture
5. Deploy and monitor
