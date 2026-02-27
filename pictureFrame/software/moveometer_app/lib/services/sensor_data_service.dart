import 'package:supabase_flutter/supabase_flutter.dart';

class SensorReading {
  final DateTime timestamp;
  final int humanExistence;
  final int motionDetected;
  final int bodyMovement;
  final int fallState; // 0 = no fall, 1 = fall detected (fall_detection mode only)

  const SensorReading({
    required this.timestamp,
    required this.humanExistence,
    required this.motionDetected,
    required this.bodyMovement,
    this.fallState = 0,
  });

  factory SensorReading.fromMap(Map<String, dynamic> map) {
    final ts = map['device_timestamp'] as String? ?? map['created_at'] as String;
    return SensorReading(
      timestamp: DateTime.parse(ts).toLocal(),
      humanExistence: (map['human_existence'] as num?)?.toInt() ?? 0,
      motionDetected: (map['motion_detected'] as num?)?.toInt() ?? 0,
      bodyMovement: (map['body_movement'] as num?)?.toInt() ?? 0,
      fallState: (map['fall_state'] as num?)?.toInt() ?? 0,
    );
  }
}

class HourlyAggregate {
  final int hour;
  final double avgBodyMovement;
  final int totalPresenceTimeSec;
  final int totalMotionEvents;

  const HourlyAggregate({
    required this.hour,
    required this.avgBodyMovement,
    required this.totalPresenceTimeSec,
    required this.totalMotionEvents,
  });

  factory HourlyAggregate.fromMap(Map<String, dynamic> map) {
    return HourlyAggregate(
      hour: (map['hour'] as num?)?.toInt() ?? 0,
      avgBodyMovement: (map['avg_body_movement'] as num?)?.toDouble() ?? 0.0,
      totalPresenceTimeSec: (map['total_presence_time_sec'] as num?)?.toInt() ?? 0,
      totalMotionEvents: (map['total_motion_events'] as num?)?.toInt() ?? 0,
    );
  }
}

class DaySummary {
  final DateTime date;
  final List<HourlyAggregate> hours;

  const DaySummary({required this.date, required this.hours});

  int get totalPresenceMinutes =>
      hours.fold(0, (sum, h) => sum + (h.totalPresenceTimeSec ~/ 60));

  int get totalMotionEvents =>
      hours.fold(0, (sum, h) => sum + h.totalMotionEvents);

  double get maxBodyMovement => hours.isEmpty
      ? 0.0
      : hours.map((h) => h.avgBodyMovement).reduce((a, b) => a > b ? a : b);
}

class SensorDataService {
  final SupabaseClient _supabase;

  SensorDataService(this._supabase);

  /// Fetch last hour of raw sensor readings, downsampled to ≤300 points.
  /// Excludes keep_alive records (they carry no real sensor values).
  /// Filtered by [sensorMode] ('sleep' or 'fall_detection').
  Future<List<SensorReading>> fetchLastHourData(
    String deviceId, {
    String sensorMode = 'sleep',
  }) async {
    final now = DateTime.now().toUtc();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    // Order DESCENDING so limit(3600) always captures the most recent data.
    // Reverse after fetch to restore chronological order for the chart.
    final response = await _supabase
        .from('mmwave_sensor_data')
        .select('device_timestamp, human_existence, motion_detected, body_movement, fall_state, sensor_mode')
        .eq('device_id', deviceId)
        .gte('device_timestamp', oneHourAgo.toIso8601String())
        .not('device_timestamp', 'is', null)
        .neq('data_type', 'keep_alive')
        .eq('sensor_mode', sensorMode)
        .order('device_timestamp', ascending: false)
        .limit(3600);

    final readings = (response as List)
        .map((m) => SensorReading.fromMap(m as Map<String, dynamic>))
        .toList()
        .reversed
        .toList(); // oldest → newest for chart plotting

    // Downsample to max 300 points for chart performance
    if (readings.length > 300) {
      final step = readings.length ~/ 300;
      return [for (int i = 0; i < readings.length; i += step) readings[i]];
    }

    return readings;
  }

  /// Fetch all record timestamps from the last hour (including keep_alive pings),
  /// used for accurate online/offline detection in the chart.
  Future<List<DateTime>> fetchActivityTimestamps(
    String deviceId, {
    String sensorMode = 'sleep',
  }) async {
    final now = DateTime.now().toUtc();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    final response = await _supabase
        .from('mmwave_sensor_data')
        .select('device_timestamp')
        .eq('device_id', deviceId)
        .gte('device_timestamp', oneHourAgo.toIso8601String())
        .not('device_timestamp', 'is', null)
        .eq('sensor_mode', sensorMode)
        .order('device_timestamp', ascending: false)
        .limit(3600);

    return (response as List)
        .map((m) {
          final ts = (m as Map<String, dynamic>)['device_timestamp'] as String;
          return DateTime.parse(ts).toLocal();
        })
        .toList()
        .reversed
        .toList();
  }

  /// Fetch pre-computed hourly aggregates for the last [days] days.
  /// If no data exists yet, automatically generates it via Supabase RPC
  /// then re-fetches. This handles the first-run case without manual backfill.
  Future<List<DaySummary>> fetchDailySummaries(
    String deviceId, {
    int days = 7,
  }) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    final startDateStr = _dateStr(startDate);

    var allRows = await _queryDailyAggregates(deviceId, startDateStr);

    // If empty, auto-generate via RPC then re-fetch
    if (allRows.isEmpty) {
      await _generateDailyAggregates(deviceId, days);
      allRows = await _queryDailyAggregates(deviceId, startDateStr);
    }

    return _groupIntoSummaries(allRows);
  }

  Future<List<Map<String, dynamic>>> _queryDailyAggregates(
    String deviceId,
    String startDateStr,
  ) async {
    final response = await _supabase
        .from('daily_aggregates')
        .select(
          'date, hour, avg_body_movement, total_presence_time_sec, total_motion_events',
        )
        .eq('device_id', deviceId)
        .gte('date', startDateStr)
        .order('date', ascending: false)
        .order('hour', ascending: true);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Call generate_daily_aggregates RPC for each of the last [days] days.
  Future<void> _generateDailyAggregates(String deviceId, int days) async {
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      try {
        await _supabase.rpc('generate_daily_aggregates', params: {
          'target_device_id': deviceId,
          'target_date': _dateStr(date),
        });
      } catch (_) {
        // Continue even if one day fails
      }
    }
  }

  List<DaySummary> _groupIntoSummaries(List<Map<String, dynamic>> allRows) {
    final Map<String, List<HourlyAggregate>> grouped = {};
    for (final row in allRows) {
      final dateStr = row['date'] as String;
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(HourlyAggregate.fromMap(row));
    }

    return grouped.entries.map((entry) {
      return DaySummary(
        date: DateTime.parse(entry.key),
        hours: entry.value..sort((a, b) => a.hour.compareTo(b.hour)),
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
