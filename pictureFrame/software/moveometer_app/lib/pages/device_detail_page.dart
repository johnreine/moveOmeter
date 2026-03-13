import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/sensor_data_service.dart';
import '../services/settings_service.dart';
import 'day_detail_page.dart';
import 'device_settings_page.dart';

class DeviceDetailPage extends StatefulWidget {
  final Map<String, dynamic> device;

  const DeviceDetailPage({super.key, required this.device});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  late final SensorDataService _service;
  final _settingsService = SettingsService();
  final _supabase = Supabase.instance.client;
  late final String _deviceId;
  late final String _locationName;
  late final String _sensorMode;

  List<SensorReading>? _hourlyReadings;
  List<DaySummary>? _dailySummaries;
  DailyMetrics? _todayMetrics;
  List<DailyMetrics>? _weeklyMetrics;

  // Device status from database (server-side calculated)
  String _connectionStatus = 'unknown';
  int _secondsSinceLastData = 0;
  int _connectionQualityScore = 0;

  bool _loadingHourly = true;
  bool _loadingDaily = true;
  bool _loadingMetrics = true;
  String? _hourlyError;
  String? _dailyError;
  String? _metricsError;
  DateTime? _lastHourlyRefresh;
  bool _use24HourFormat = false;

  Timer? _refreshTimer;
  Timer? _clockTimer; // Ticks every 10s to update "Updated X ago" display

  @override
  void initState() {
    super.initState();
    _service = SensorDataService(Supabase.instance.client);
    _deviceId = widget.device['device_id'] as String;
    _locationName = widget.device['location_name'] as String? ?? _deviceId;
    _sensorMode = widget.device['operational_mode'] as String? ?? 'sleep';

    _loadSettings();
    _loadHourlyData();
    _loadDailyData();
    _loadMetricsData();

    // Refresh data every 30 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadHourlyData(),
    );

    // Update "Updated X ago" display every 10 seconds
    _clockTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) { if (mounted) setState(() {}); },
    );
  }

  Future<void> _loadSettings() async {
    final use24h = await _settingsService.getUse24HourFormat();
    if (mounted) {
      setState(() => _use24HourFormat = use24h);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceStatus() async {
    try {
      // Load device status from database (server-side calculated)
      final response = await _supabase
          .from('moveometers')
          .select('connection_status, seconds_since_last_data, connection_quality_score')
          .eq('device_id', _deviceId)
          .single();

      if (mounted) {
        setState(() {
          _connectionStatus = response['connection_status'] as String? ?? 'unknown';
          _secondsSinceLastData = response['seconds_since_last_data'] as int? ?? 0;
          _connectionQualityScore = response['connection_quality_score'] as int? ?? 0;
        });
      }
    } catch (e) {
      print('Error loading device status: $e');
    }
  }

  Future<void> _loadHourlyData() async {
    try {
      final readings = await _service.fetchLastHourData(_deviceId, sensorMode: _sensorMode);
      // Load device status from database
      await _loadDeviceStatus();

      if (mounted) {
        setState(() {
          _hourlyReadings = readings;
          _loadingHourly = false;
          _hourlyError = null;
          _lastHourlyRefresh = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hourlyError = e.toString();
          _loadingHourly = false;
        });
      }
    }
  }

  Future<void> _loadDailyData() async {
    try {
      final summaries = await _service.fetchDailySummaries(_deviceId);
      if (mounted) {
        setState(() {
          _dailySummaries = summaries;
          _loadingDaily = false;
          _dailyError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dailyError = e.toString();
          _loadingDaily = false;
        });
      }
    }
  }

  Future<void> _loadMetricsData() async {
    try {
      final today = await _service.fetchTodayMetrics(_deviceId);
      final weekly = await _service.fetchDailyMetrics(_deviceId, days: 7);
      if (mounted) {
        setState(() {
          _todayMetrics = today;
          _weeklyMetrics = weekly;
          _loadingMetrics = false;
          _metricsError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _metricsError = e.toString();
          _loadingMetrics = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loadingHourly = true;
      _loadingDaily = true;
      _loadingMetrics = true;
    });
    await Future.wait([_loadHourlyData(), _loadDailyData(), _loadMetricsData()]);
  }

  Future<void> _refreshDeviceData() async {
    try {
      final response = await Supabase.instance.client
          .from('moveometers')
          .select()
          .eq('device_id', _deviceId)
          .single();

      if (mounted && response != null) {
        setState(() {
          _locationName = response['location_name'] as String? ?? _deviceId;
        });
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.device['operational_mode'] as String? ?? 'sleep';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_locationName, overflow: TextOverflow.ellipsis),
            Text(
              mode.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceSettingsPage(device: widget.device),
                ),
              );
              // If settings were changed, refresh the device data and sensor data
              if (result == true) {
                await _refreshDeviceData();
                _refreshAll();
              }
            },
            tooltip: 'Device Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHourlySection(),
            const SizedBox(height: 16),
            _buildTodayMetricsSection(),
            const SizedBox(height: 16),
            _buildWeeklyMetricsSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 1-Hour Section
  // ─────────────────────────────────────────────────────────

  // Device status from database (server-side calculated)
  // Returns true = online, false = offline, null = unknown
  bool? get _deviceOnlineStatus {
    if (_connectionStatus == 'unknown') return null;
    return _connectionStatus == 'online';
  }

  Widget _buildHourlySection() {
    final online = _deviceOnlineStatus;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Last Hour',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                // Online/offline status chip
                if (online != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: online
                          ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                          : const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: online
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: online
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          online ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: online
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (_lastHourlyRefresh != null)
                  Flexible(
                    child: Text(
                      'Updated ${_timeSince(_lastHourlyRefresh!)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            // Legend
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _legendDot(const Color(0xFF22C55E), 'Presence'),
                _legendDot(const Color(0xFF8B5CF6), 'Movement'),
                if (_sensorMode == 'fall_detection')
                  _legendDot(const Color(0xFFEF4444), 'Fall'),
              ],
            ),
            // Fall alert banner
            if (_sensorMode == 'fall_detection' &&
                _hourlyReadings != null &&
                _hourlyReadings!.any((r) => r.fallState > 0))
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fall detected in the last hour',
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (_loadingHourly)
              const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hourlyError != null)
              _errorWidget(_hourlyError!, _loadHourlyData)
            else
              SizedBox(
                height: 180,
                child: _buildHourlyChart(_hourlyReadings ?? [], []),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyChart(
    List<SensorReading> readings,
    List<DateTime> _unusedActivityTimestamps, // No longer needed - status from DB
  ) {
    // Anchor x-axis to a fixed 60-minute window ending at "now"
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    const double windowSecs = 3600;

    // Normalize body_movement to 0–1 using the max in this dataset
    final maxMovement = readings
        .map((r) => r.bodyMovement)
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();
    final movementScale = maxMovement > 0 ? maxMovement : 1.0;

    // ── Build sensor data spots (presence & movement lines) ──────────────
    // Gap threshold for dropping lines to zero: 65s (2 missed pings + buffer)
    const double gapThreshold = 65.0;
    final List<FlSpot> existenceSpots = [];
    final List<FlSpot> movementSpots = [];
    double? prevX;

    for (final r in readings) {
      final x = r.timestamp.difference(oneHourAgo).inSeconds.toDouble();
      if (x < 0 || x > windowSecs) continue;

      if (prevX != null && x - prevX > gapThreshold) {
        // Drop lines to zero at gap boundaries so the chart doesn't bridge
        existenceSpots.add(FlSpot(prevX + 1, 0.0));
        movementSpots.add(FlSpot(prevX + 1, 0.0));
        existenceSpots.add(FlSpot(x - 1, 0.0));
        movementSpots.add(FlSpot(x - 1, 0.0));
      }

      existenceSpots.add(FlSpot(x, r.humanExistence.toDouble()));
      movementSpots.add(FlSpot(x, r.bodyMovement / movementScale));
      prevX = x;
    }

    // No longer calculating offline periods client-side
    // Device status comes from database

    const green = Color(0xFF22C55E);
    const purple = Color(0xFF8B5CF6);
    const red = Color(0xFFEF4444);

    // ── Fall event markers (fall_detection mode only) ─────────────────────
    final fallSpots = readings
        .where((r) => r.fallState > 0)
        .map((r) {
          final x = r.timestamp.difference(oneHourAgo).inSeconds.toDouble();
          return FlSpot(x.clamp(0.0, windowSecs), 0.5);
        })
        .toList();

    // No longer showing offline overlays - status comes from database

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: windowSecs,
        minY: -0.05,
        maxY: 1.2,
        clipData: FlClipData.all(),
        lineBarsData: [
          // Presence — filled area shows when person is detected
          LineChartBarData(
            spots: existenceSpots,
            isCurved: false,
            color: green,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: green.withValues(alpha: 0.15),
            ),
          ),
          // Body movement normalized to 0–1 (dimmed)
          if (maxMovement > 0)
            LineChartBarData(
              spots: movementSpots,
              isCurved: false,
              color: purple.withValues(alpha: 0.35),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          // Fall event markers — red circles at y=0.5
          if (fallSpots.isNotEmpty)
            LineChartBarData(
              spots: fallSpots,
              color: Colors.transparent,
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 7,
                  color: red,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const Text('off', style: TextStyle(fontSize: 9, color: Colors.grey));
                }
                if (value == 1) {
                  return const Text('on', style: TextStyle(fontSize: 9, color: Colors.grey));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 900, // label every 15 minutes
              getTitlesWidget: (value, meta) {
                // Guard: only label at exact 15-min marks within range
                if (value < 0 || value > windowSecs + 60) {
                  return const SizedBox.shrink();
                }
                final t = oneHourAgo.add(Duration(seconds: value.toInt()));
                final timeFormat = _use24HourFormat ? 'HH:mm' : 'h:mm a';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat(timeFormat).format(t),
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 900,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
          getDrawingVerticalLine: (v) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.12), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Today's Metrics Section
  // ─────────────────────────────────────────────────────────

  Widget _buildTodayMetricsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DayDetailPage(
                device: widget.device,
                date: DateTime.now(),
                metrics: _todayMetrics,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Today\'s Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF667eea), width: 1),
                    ),
                    child: const Text(
                      'IN PROGRESS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF667eea),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (_loadingMetrics)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_metricsError != null)
              _errorWidget(_metricsError!, _loadMetricsData)
            else if (_todayMetrics == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No data yet today',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              _buildTodayMetricsContent(_todayMetrics!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayMetricsContent(DailyMetrics m) {
    return Column(
      children: [
        // Motion Score
        if (m.motionScore != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getScoreColor(m.motionScore!).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${m.motionScore}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(m.motionScore!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motion Score',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    _getScoreLabel(m.motionScore!),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(m.motionScore!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Quick stats grid
        Row(
          children: [
            if (m.totalActiveMinutes != null)
              Expanded(
                child: _metricTile(
                  '${m.totalActiveMinutes}',
                  'Active Min',
                  Icons.directions_run,
                  const Color(0xFF22C55E),
                ),
              ),
            if (m.movementSessions != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  '${m.movementSessions}',
                  'Sessions',
                  Icons.swap_horiz,
                  const Color(0xFF06B6D4),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Only show first motion for today (last motion doesn't make sense until day is complete)
        if (m.firstMotionTime != null)
          _metricTile(
            DateFormat(_use24HourFormat ? 'HH:mm' : 'h:mm a').format(m.firstMotionTime!),
            'First Motion',
            Icons.wb_sunny,
            const Color(0xFFFB923C),
          ),
      ],
    );
  }

  Widget _metricTile(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Weekly Metrics Section
  // ─────────────────────────────────────────────────────────

  Widget _buildWeeklyMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Past 7 Days',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_loadingMetrics)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_metricsError != null)
          _errorWidget(_metricsError!, _loadMetricsData)
        else if (_weeklyMetrics == null || _weeklyMetrics!.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No daily metrics yet',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Metrics are calculated daily',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._weeklyMetrics!.map(_buildWeeklyMetricCard),
      ],
    );
  }

  Widget _buildWeeklyMetricCard(DailyMetrics metrics) {
    final isToday = _isSameDay(metrics.date, DateTime.now());
    final label = isToday
        ? 'Today'
        : DateFormat('EEEE, MMM d').format(metrics.date);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DayDetailPage(
                device: widget.device,
                date: metrics.date,
                metrics: metrics,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isToday ? const Color(0xFF667eea) : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (metrics.motionScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getScoreColor(metrics.motionScore!)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${metrics.motionScore}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(metrics.motionScore!),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (metrics.totalActiveMinutes != null) ...[
                    Icon(Icons.directions_run,
                        size: 14, color: const Color(0xFF22C55E)),
                    const SizedBox(width: 4),
                    Text(
                      '${metrics.totalActiveMinutes} min',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (metrics.movementSessions != null) ...[
                    Icon(Icons.swap_horiz,
                        size: 14, color: const Color(0xFF06B6D4)),
                    const SizedBox(width: 4),
                    Text(
                      '${metrics.movementSessions} sessions',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                  if (metrics.fallCount != null && metrics.fallCount! > 0) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: const Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    Text(
                      '${metrics.fallCount} falls',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Daily History Section (Old Hourly Aggregates)
  // ─────────────────────────────────────────────────────────

  Widget _buildDailySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily History',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_loadingDaily)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_dailyError != null)
          _errorWidget(_dailyError!, _loadDailyData)
        else if (_dailySummaries == null || _dailySummaries!.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No daily data yet',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Daily summaries are computed each hour.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._dailySummaries!.map(_buildDayCard),
      ],
    );
  }

  Widget _buildDayCard(DaySummary day) {
    final isToday = _isSameDay(day.date, DateTime.now());
    final label = isToday
        ? 'Today'
        : DateFormat('EEEE, MMM d').format(day.date);

    final presenceHours = (day.totalPresenceMinutes / 60).toStringAsFixed(1);
    final maxMovement = day.maxBodyMovement;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? const Color(0xFF667eea) : Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d').format(day.date),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Stats row
            Row(
              children: [
                _statChip(
                  Icons.person,
                  '$presenceHours hrs',
                  'Presence',
                  const Color(0xFF22C55E),
                ),
                const SizedBox(width: 12),
                _statChip(
                  Icons.directions_run,
                  '${day.totalMotionEvents}',
                  'Motion events',
                  const Color(0xFFFB923C),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Hourly bar chart
            if (day.hours.isEmpty)
              const Text(
                'No hourly data',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              )
            else
              SizedBox(
                height: 100,
                child: _buildDayBarChart(day, maxMovement),
              ),
            const SizedBox(height: 4),
            const Text(
              'Activity by hour (midnight → midnight)',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayBarChart(DaySummary day, double globalMax) {
    // Build a map of hour → aggregate for quick lookup
    final Map<int, HourlyAggregate> byHour = {
      for (final h in day.hours) h.hour: h,
    };

    final maxY = globalMax > 0 ? globalMax : 10.0;

    // Build all 24 bars
    final groups = List.generate(24, (hour) {
      final agg = byHour[hour];
      final value = agg?.avgBodyMovement ?? 0.0;
      final hasPresence = (agg?.totalPresenceTimeSec ?? 0) > 0;

      return BarChartGroupData(
        x: hour,
        barRods: [
          BarChartRodData(
            toY: value,
            color: hasPresence
                ? const Color(0xFF667eea).withValues(alpha: 0.75)
                : Colors.grey.withValues(alpha: 0.2),
            width: 7,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
        ],
      );
    });

    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        barGroups: groups,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              interval: 6, // Show labels at midnight, 6am, noon, 6pm
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0:
                    return const Text('12a', style: TextStyle(fontSize: 9));
                  case 6:
                    return const Text('6a', style: TextStyle(fontSize: 9));
                  case 12:
                    return const Text('12p', style: TextStyle(fontSize: 9));
                  case 18:
                    return const Text('6p', style: TextStyle(fontSize: 9));
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 2,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _errorWidget(String message, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 36),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _timeSince(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _getScoreColor(int score) {
    if (score >= 70) return const Color(0xFF22C55E);
    if (score >= 40) return const Color(0xFFFB923C);
    return const Color(0xFFEF4444);
  }

  String _getScoreLabel(int score) {
    if (score >= 70) return 'Very Active';
    if (score >= 40) return 'Moderate';
    return 'Low Activity';
  }
}
