# Time Accuracy Setup - moveOmeter

## 🎯 Problem Solved

**Before:** Timestamps were inaccurate!
- ❌ ESP32-C6 had no real-time clock
- ❌ Used `created_at` = when Supabase **received** data (not when reading was taken)
- ❌ WiFi delays caused wrong timestamps
- ❌ 10 second WiFi lag = 10 second timestamp error!

**After:** Accurate, NTP-synced timestamps!
- ✅ ESP32-C6 syncs with NTP time servers
- ✅ `device_timestamp` = exact moment sensor reading was taken
- ✅ Auto-resyncs every 5 minutes for drift correction
- ✅ Uses 3 redundant NTP servers (pool.ntp.org, time.nist.gov, time.google.com)
- ✅ Dashboard uses device time for accurate charts

---

## 📊 Timestamp Fields Explained

Your Supabase table now has **TWO timestamps**:

### 1. `device_timestamp` (NEW - Use This!)
**What it is:** Exact time the sensor reading was taken (from device's NTP-synced clock)

**Format:** ISO 8601 with timezone
```
2026-02-02T14:32:15-08:00
```

**Accuracy:** ±50ms (NTP sync)

**Use for:**
- ✅ Charts and graphs
- ✅ Data analysis
- ✅ Event timelines
- ✅ "What time did person enter bathroom?"

### 2. `created_at` (Keep for Debugging)
**What it is:** When Supabase server received the data

**Use for:**
- Debugging upload delays
- Detecting WiFi issues
- Network performance monitoring

**Example comparison:**
```sql
SELECT
    device_timestamp,      -- 14:32:15 (reading taken)
    created_at,            -- 14:32:17 (received 2 seconds later)
    created_at - device_timestamp as delay
FROM mmwave_sensor_data;
```

---

## 🚀 Setup Steps

### Step 1: Update Database (Required)

Run this SQL in Supabase:
```bash
cat /Users/johnreine/Dropbox/john/2025_work/moveOmeter/database/add_device_timestamp.sql
```

Or copy/paste into Supabase SQL Editor.

**What it does:**
- Adds `device_timestamp` column
- Creates indexes for performance
- Creates debugging view to compare timestamps

### Step 2: Timezone Configuration

**No configuration needed!** ✅

All timestamps are stored in **UTC** (Universal Time):
- Arduino records time in UTC
- Supabase stores in UTC
- Web UI automatically converts to **your local time**

**Benefits:**
- ✅ Works anywhere in the world
- ✅ No DST confusion
- ✅ Multiple devices in different timezones = no problem
- ✅ Standard database practice

### Step 3: Upload Updated Firmware

1. Open Arduino IDE
2. Load `mmWave_Supabase_collector.ino`
3. Upload to ESP32-C6
4. Open Serial Monitor

**You should see:**
```
Syncing time with NTP servers... SUCCESS!
Current time: 2026-02-02 14:32:15
```

### Step 4: Verify Time Accuracy

**Check Serial Monitor output:**
```json
{
  "device_timestamp": "2026-02-02T14:32:15-08:00",
  ...
}
```

**Check Supabase:**
```sql
SELECT device_id, device_timestamp, created_at
FROM mmwave_sensor_data
ORDER BY created_at DESC
LIMIT 5;
```

Timestamps should look correct!

### Step 5: Refresh Dashboard

Dashboard automatically uses `device_timestamp` now. Just refresh (Cmd+Shift+R).

---

## 🔧 How NTP Time Sync Works

### On Device Boot:
1. Connect to WiFi
2. Contact NTP servers (pool.ntp.org, time.nist.gov, time.google.com)
3. Synchronize internal clock
4. Takes ~1-2 seconds

### During Operation:
- **Every 5 minutes:** Resync with NTP servers
- Corrects clock drift (ESP32 crystal can drift 1-2 seconds/day)
- Uses 3 servers for redundancy (if one is down, tries others)

### NTP Servers Used:
1. **pool.ntp.org** - Global pool of time servers
2. **time.nist.gov** - NIST (US government standard)
3. **time.google.com** - Google's public NTP

**Accuracy:** ±50 milliseconds over internet, ±1ms on local network

---

## 📈 Dashboard Updates

**Charts now use `device_timestamp`:**
- X-axis shows exact time of sensor reading
- No more timestamp delays from WiFi
- Accurate event timelines

**Fallback behavior:**
- If `device_timestamp` missing (old data), uses `created_at`
- Backward compatible with existing data

---

## 🐛 Troubleshooting

### Time shows as 1970-01-01
**Problem:** NTP sync failed

**Fix:**
1. Check WiFi connection
2. Verify NTP servers accessible:
   ```bash
   ping pool.ntp.org
   ```
3. Check firewall allows NTP (UDP port 123)
4. Try different NTP servers

### Time is wrong by hours
**Problem:** Timezone offset incorrect

**Fix:** Adjust `GMT_OFFSET_SEC` in code:
```cpp
#define GMT_OFFSET_SEC -28800  // Your offset here
```

### Time drifts over days
**Problem:** NTP resync not working

**Fix:**
- Check Serial Monitor for "Resyncing time with NTP..."
- Should happen every 5 minutes
- Increase sync frequency if needed

### Delay between device_timestamp and created_at
**Problem:** WiFi latency or buffering

**Check delay:**
```sql
SELECT
    device_id,
    EXTRACT(EPOCH FROM (created_at - device_timestamp)) as delay_seconds
FROM mmwave_sensor_data
ORDER BY created_at DESC;
```

**Normal:** 0.5-2 seconds
**High:** 5-10 seconds (check WiFi signal)
**Very high:** 30+ seconds (WiFi issues or device buffering)

---

## 🎓 Technical Details

### ISO 8601 UTC Format
```
2026-02-02T14:32:15Z
│          │        │
│          │        └─ Z = UTC (Zulu time)
│          └─ Time (HH:MM:SS)
└─ Date (YYYY-MM-DD)
```

**Why UTC?**
- Universal standard (no timezone confusion)
- Works globally (same timestamp everywhere)
- No DST issues (UTC doesn't change)
- Database best practice
- Browser automatically converts to local

**Example:**
```
Device records:  2026-02-02T22:32:15Z  (UTC)
Database stores: 2026-02-02T22:32:15Z  (UTC)
LA user sees:    2:32:15 PM PST        (Local)
NY user sees:    5:32:15 PM EST        (Local)
London sees:     10:32:15 PM GMT       (Local)
```

**Why ISO 8601?**
- Standard format
- Sortable as string
- Supabase native support
- JavaScript Date() handles it automatically

### Time Storage in PostgreSQL
```sql
device_timestamp TIMESTAMPTZ
```
- `TIMESTAMPTZ` = Timestamp with timezone
- Stored in UTC internally
- Displayed in your timezone automatically
- Handles DST transitions

### NTP Protocol
- **Accuracy:** ±50ms over internet
- **Frequency:** Every 5 minutes
- **Servers:** 3 redundant sources
- **Port:** UDP 123

---

## ✅ Benefits

1. **Accurate event timing** - Know exact moment fall occurred
2. **Reliable analytics** - Charts based on real sensor time
3. **Debug network issues** - Compare device_timestamp vs created_at
4. **Multiple devices sync** - All devices use same time source
5. **Survives WiFi delays** - Timestamp recorded before upload
6. **Clock drift correction** - Auto-resyncs every 5 minutes

---

## 📊 Example Queries

### Find delays in data upload
```sql
SELECT
    device_id,
    device_timestamp,
    created_at,
    EXTRACT(EPOCH FROM (created_at - device_timestamp)) as delay_sec
FROM mmwave_sensor_data
WHERE EXTRACT(EPOCH FROM (created_at - device_timestamp)) > 5
ORDER BY delay_sec DESC;
```

### Events in last hour (accurate)
```sql
SELECT *
FROM mmwave_sensor_data
WHERE device_timestamp > NOW() - INTERVAL '1 hour'
ORDER BY device_timestamp DESC;
```

### Time-of-day analysis
```sql
SELECT
    EXTRACT(HOUR FROM device_timestamp) as hour_of_day,
    COUNT(*) as events
FROM mmwave_sensor_data
WHERE sensor_mode = 'fall_detection'
GROUP BY hour_of_day
ORDER BY hour_of_day;
```

---

## 🎯 Summary

**You now have:**
- ✅ NTP-synced time on ESP32-C6
- ✅ Accurate `device_timestamp` field
- ✅ Auto-resync every 5 minutes
- ✅ Dashboard using device time
- ✅ Tools to debug timing issues

**Your timestamps are now accurate to ±50 milliseconds!** 🎉
