import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/sensor_data_service.dart';
import '../services/settings_service.dart';

class DayDetailPage extends StatefulWidget {
  final Map<String, dynamic> device;
  final DateTime date;
  final DailyMetrics? metrics;

  const DayDetailPage({
    super.key,
    required this.device,
    required this.date,
    this.metrics,
  });

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  late final SensorDataService _service;
  final _settingsService = SettingsService();
  late final String _deviceId;
  late final String _locationName;
  late final String _sensorMode;

  List<SensorReading>? _dayReadings;
  DailyMetrics? _metrics;

  bool _loading = true;
  String? _error;
  bool _use24HourFormat = false;

  @override
  void initState() {
    super.initState();
    _service = SensorDataService(Supabase.instance.client);
    _deviceId = widget.device['device_id'] as String;
    _locationName = widget.device['location_name'] as String? ?? _deviceId;
    _sensorMode = widget.device['operational_mode'] as String? ?? 'sleep';
    _metrics = widget.metrics;

    _loadSettings();
    _loadDayData();
  }

  Future<void> _loadSettings() async {
    final use24h = await _settingsService.getUse24HourFormat();
    if (mounted) {
      setState(() => _use24HourFormat = use24h);
    }
  }

  Future<void> _loadDayData() async {
    try {
      final readings = await _service.fetch24HourData(
        _deviceId,
        widget.date,
        sensorMode: _sensorMode,
      );

      // Fetch metrics if not provided
      if (_metrics == null) {
        final allMetrics = await _service.fetchDailyMetrics(_deviceId, days: 30);
        _metrics = allMetrics.firstWhere(
          (m) => _isSameDay(m.date, widget.date),
          orElse: () => DailyMetrics(date: widget.date),
        );
      }

      if (mounted) {
        setState(() {
          _dayReadings = readings;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(widget.date, DateTime.now());
    final dateLabel = isToday
        ? 'Today'
        : DateFormat('EEEE, MMMM d, y').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_locationName, overflow: TextOverflow.ellipsis),
            Text(
              dateLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _loading = true);
          await _loadDayData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMetricsCard(),
            const SizedBox(height: 16),
            _build24HourChart(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard() {
    if (_metrics == null) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No metrics available for this day')),
        ),
      );
    }

    final m = _metrics!;
    final isToday = _isSameDay(widget.date, DateTime.now());

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
                  'Daily Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isToday) ...[
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
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Motion Score
            if (m.motionScore != null) ...[
              _buildMetricRow(
                'Motion Score',
                '${m.motionScore}/100',
                Icons.insights,
                _getScoreColor(m.motionScore!),
              ),
              const Divider(height: 24),
            ],

            // Wake/Sleep Times
            if (m.firstMotionTime != null || m.lastMotionTime != null) ...[
              Row(
                children: [
                  if (m.firstMotionTime != null)
                    Expanded(
                      child: _buildMetricRow(
                        'First Motion',
                        DateFormat(_use24HourFormat ? 'HH:mm' : 'h:mm a').format(m.firstMotionTime!),
                        Icons.wb_sunny,
                        const Color(0xFFFB923C),
                      ),
                    ),
                  if (m.firstMotionTime != null && m.lastMotionTime != null)
                    const SizedBox(width: 16),
                  if (m.lastMotionTime != null)
                    Expanded(
                      child: _buildMetricRow(
                        'Last Motion',
                        DateFormat(_use24HourFormat ? 'HH:mm' : 'h:mm a').format(m.lastMotionTime!),
                        Icons.bedtime,
                        const Color(0xFF8B5CF6),
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),
            ],

            // Activity Stats
            Row(
              children: [
                if (m.totalActiveMinutes != null)
                  Expanded(
                    child: _buildMetricRow(
                      'Active Time',
                      '${m.totalActiveMinutes} min',
                      Icons.directions_run,
                      const Color(0xFF22C55E),
                    ),
                  ),
                if (m.totalActiveMinutes != null && m.movementSessions != null)
                  const SizedBox(width: 16),
                if (m.movementSessions != null)
                  Expanded(
                    child: _buildMetricRow(
                      'Sessions',
                      '${m.movementSessions}',
                      Icons.swap_horiz,
                      const Color(0xFF06B6D4),
                    ),
                  ),
              ],
            ),

            if (m.longestStationaryMinutes != null ||
                m.offlineMinutes != null ||
                m.peakActivityHour != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  if (m.longestStationaryMinutes != null)
                    Expanded(
                      child: _buildMetricRow(
                        'Longest Still',
                        '${m.longestStationaryMinutes} min',
                        Icons.chair,
                        Colors.grey,
                      ),
                    ),
                  if (m.longestStationaryMinutes != null && m.peakActivityHour != null)
                    const SizedBox(width: 16),
                  if (m.peakActivityHour != null)
                    Expanded(
                      child: _buildMetricRow(
                        'Peak Hour',
                        _formatHour(m.peakActivityHour!),
                        Icons.trending_up,
                        const Color(0xFFFB923C),
                      ),
                    ),
                ],
              ),
            ],

            // Falls & Data Quality
            if (m.fallCount != null && m.fallCount! > 0) ...[
              const Divider(height: 24),
              _buildMetricRow(
                'Falls Detected',
                '${m.fallCount}',
                Icons.warning_amber_rounded,
                const Color(0xFFEF4444),
              ),
            ],

            if (m.dataCoveragePct != null) ...[
              const Divider(height: 24),
              _buildMetricRow(
                'Data Coverage',
                '${m.dataCoveragePct!.toStringAsFixed(1)}%',
                Icons.signal_cellular_alt,
                m.dataCoveragePct! > 80
                    ? const Color(0xFF22C55E)
                    : m.dataCoveragePct! > 50
                        ? const Color(0xFFFB923C)
                        : const Color(0xFFEF4444),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _build24HourChart() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '24-Hour Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                _legendDot(const Color(0xFF22C55E), 'Presence'),
                _legendDot(const Color(0xFF8B5CF6), 'Movement'),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SizedBox(
                height: 200,
                child: Center(child: Text('Error: $_error')),
              )
            else
              SizedBox(
                height: 200,
                child: _build24HourLineChart(_dayReadings ?? []),
              ),
          ],
        ),
      ),
    );
  }

  Widget _build24HourLineChart(List<SensorReading> readings) {
    if (readings.isEmpty) {
      return const Center(child: Text('No data for this day'));
    }

    final startOfDay = DateTime(widget.date.year, widget.date.month, widget.date.day);
    const double windowSecs = 86400; // 24 hours in seconds

    // Normalize movement
    final maxMovement = readings
        .map((r) => r.bodyMovement)
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();
    final movementScale = maxMovement > 0 ? maxMovement : 1.0;

    final List<FlSpot> existenceSpots = [];
    final List<FlSpot> movementSpots = [];

    for (final r in readings) {
      final x = r.timestamp.difference(startOfDay).inSeconds.toDouble();
      if (x < 0 || x > windowSecs) continue;

      existenceSpots.add(FlSpot(x, r.humanExistence.toDouble()));
      movementSpots.add(FlSpot(x, r.bodyMovement / movementScale));
    }

    const green = Color(0xFF22C55E);
    const purple = Color(0xFF8B5CF6);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: windowSecs,
        minY: -0.05,
        maxY: 1.2,
        clipData: FlClipData.all(),
        lineBarsData: [
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
          if (maxMovement > 0)
            LineChartBarData(
              spots: movementSpots,
              isCurved: false,
              color: purple.withValues(alpha: 0.35),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
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
              interval: 21600, // Every 6 hours
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > windowSecs) {
                  return const SizedBox.shrink();
                }
                final hour = (value / 3600).round();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    hour == 0 ? '12a' : hour < 12 ? '${hour}a' : hour == 12 ? '12p' : '${hour - 12}p',
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
          verticalInterval: 21600, // Every 6 hours
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
          getDrawingVerticalLine: (v) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.12), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

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

  Color _getScoreColor(int score) {
    if (score >= 70) return const Color(0xFF22C55E);
    if (score >= 40) return const Color(0xFFFB923C);
    return const Color(0xFFEF4444);
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
