import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/settings_service.dart';

class HouseDayDetailPage extends StatefulWidget {
  final Map<String, dynamic> house;
  final DateTime date;
  final Map<String, dynamic>? metrics;

  const HouseDayDetailPage({
    super.key,
    required this.house,
    required this.date,
    this.metrics,
  });

  @override
  State<HouseDayDetailPage> createState() => _HouseDayDetailPageState();
}

class _HouseDayDetailPageState extends State<HouseDayDetailPage> {
  final _supabase = Supabase.instance.client;
  final _settingsService = SettingsService();

  bool _isLoading = true;
  bool _use24HourFormat = false;
  List<Map<String, dynamic>> _hourlyData = [];
  Map<String, dynamic>? _daySummary;

  @override
  void initState() {
    super.initState();
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
    setState(() => _isLoading = true);

    try {
      final houseId = widget.house['id'];
      final dateStr = '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

      // Get all devices in this house
      final devices = await _supabase
          .from('moveometers')
          .select('device_id')
          .eq('house_id', houseId)
          .eq('device_status', 'active');

      if (devices.isEmpty) {
        setState(() {
          _isLoading = false;
          _daySummary = null;
        });
        return;
      }

      final deviceIds = (devices as List).map((d) => d['device_id'] as String).toList();

      // Get hourly data for all devices from daily_aggregates
      final allHourlyData = await _supabase
          .from('daily_aggregates')
          .select('*')
          .eq('date', dateStr)
          .inFilter('device_id', deviceIds)
          .order('hour');

      // Aggregate by hour across all devices
      final Map<int, List<Map<String, dynamic>>> hourlyGroups = {};
      for (var data in allHourlyData) {
        final hour = data['hour'] as int;
        if (!hourlyGroups.containsKey(hour)) {
          hourlyGroups[hour] = [];
        }
        hourlyGroups[hour]!.add(data);
      }

      // Calculate aggregates for each hour
      final List<Map<String, dynamic>> aggregated = [];
      for (int hour = 0; hour < 24; hour++) {
        final hourData = hourlyGroups[hour] ?? [];

        if (hourData.isEmpty) {
          aggregated.add({
            'hour': hour,
            'avg_body_movement': 0,
            'max_body_movement': 0,
            'total_motion_events': 0,
            'total_presence_time_sec': 0,
          });
        } else {
          double totalMovement = 0;
          int maxMovement = 0;
          int totalMotion = 0;
          int totalPresence = 0;

          for (var data in hourData) {
            totalMovement += (data['avg_body_movement'] as num?)?.toDouble() ?? 0;
            final deviceMax = data['max_body_movement'] as int? ?? 0;
            if (deviceMax > maxMovement) maxMovement = deviceMax;
            totalMotion += data['total_motion_events'] as int? ?? 0;
            totalPresence += data['total_presence_time_sec'] as int? ?? 0;
          }

          aggregated.add({
            'hour': hour,
            'avg_body_movement': totalMovement / hourData.length,
            'max_body_movement': maxMovement,
            'total_motion_events': totalMotion,
            'total_presence_time_sec': totalPresence,
            'device_count': hourData.length,
          });
        }
      }

      // Calculate day summary
      int totalMotionScore = 0;
      int totalActiveMinutes = 0;
      DateTime? firstMotion;
      DateTime? lastMotion;
      int deviceCount = 0;

      final dayMetrics = await _supabase
          .from('daily_aggregates')
          .select('*')
          .eq('date', dateStr)
          .inFilter('device_id', deviceIds);

      for (var metric in dayMetrics) {
        deviceCount++;
        totalMotionScore += (metric['motion_score'] as int? ?? 0);
        totalActiveMinutes += (metric['total_active_minutes'] as int? ?? 0);

        final firstMotionStr = metric['first_motion_time'] as String?;
        if (firstMotionStr != null) {
          final ft = DateTime.parse(firstMotionStr);
          if (firstMotion == null || ft.isBefore(firstMotion)) {
            firstMotion = ft;
          }
        }

        final lastMotionStr = metric['last_motion_time'] as String?;
        if (lastMotionStr != null) {
          final lt = DateTime.parse(lastMotionStr);
          if (lastMotion == null || lt.isAfter(lastMotion)) {
            lastMotion = lt;
          }
        }
      }

      final avgMotionScore = deviceCount > 0 ? (totalMotionScore / deviceCount).round() : 0;

      setState(() {
        _hourlyData = aggregated;
        _daySummary = {
          'motion_score': avgMotionScore,
          'total_active_minutes': totalActiveMinutes,
          'first_motion_time': firstMotion,
          'last_motion_time': lastMotion,
          'device_count': deviceCount,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading day data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().difference(widget.date).inDays == 0;
    final dateStr = isToday ? 'Today' : DateFormat('MMMM d, yyyy').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: Text(dateStr),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _daySummary == null
              ? const Center(child: Text('No data available for this date'))
              : RefreshIndicator(
                  onRefresh: _loadDayData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary Card
                      _buildSummaryCard(),
                      const SizedBox(height: 16),

                      // 24-Hour Timeline Graph
                      _buildTimelineGraph(),
                      const SizedBox(height: 16),

                      // Hourly Breakdown
                      _buildHourlyBreakdown(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    final motionScore = _daySummary!['motion_score'] as int;
    final activeMinutes = _daySummary!['total_active_minutes'] as int;
    final firstMotion = _daySummary!['first_motion_time'] as DateTime?;
    final lastMotion = _daySummary!['last_motion_time'] as DateTime?;
    final deviceCount = _daySummary!['device_count'] as int;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home, color: Color(0xFF667eea)),
                const SizedBox(width: 8),
                Text(
                  'House Summary ($deviceCount device${deviceCount != 1 ? 's' : ''})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Motion Score',
                    '$motionScore',
                    _getScoreColor(motionScore),
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Active Time',
                    '${activeMinutes}min',
                    const Color(0xFF667eea),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'First Motion',
                    firstMotion != null
                        ? DateFormat(_use24HourFormat ? 'HH:mm' : 'h:mm a').format(firstMotion)
                        : 'No data',
                    Colors.grey[700]!,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Last Motion',
                    lastMotion != null
                        ? DateFormat(_use24HourFormat ? 'HH:mm' : 'h:mm a').format(lastMotion)
                        : 'No data',
                    Colors.grey[700]!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineGraph() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '24-Hour Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[200]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 4,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          if (hour < 0 || hour > 23) return const SizedBox.shrink();
                          if (_use24HourFormat) {
                            return Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(fontSize: 9),
                            );
                          } else {
                            final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                            final period = hour < 12 ? 'a' : 'p';
                            return Text(
                              '$displayHour$period',
                              style: const TextStyle(fontSize: 9),
                            );
                          }
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 23,
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _hourlyData.map((data) {
                        final hour = data['hour'] as int;
                        final movement = (data['avg_body_movement'] as num).toDouble();
                        return FlSpot(hour.toDouble(), movement.clamp(0, 100));
                      }).toList(),
                      isCurved: true,
                      color: const Color(0xFF667eea),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF667eea).withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyBreakdown() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hourly Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._hourlyData.where((data) {
              return (data['total_motion_events'] as int) > 0 ||
                     (data['total_presence_time_sec'] as int) > 0;
            }).map((data) {
              final hour = data['hour'] as int;
              final movement = (data['avg_body_movement'] as num).toDouble().toStringAsFixed(1);
              final motionEvents = data['total_motion_events'] as int;
              final deviceCount = data['device_count'] as int? ?? 0;

              final hourTime = DateTime(widget.date.year, widget.date.month, widget.date.day, hour);
              final hourStr = DateFormat(_use24HourFormat ? 'HH:00' : 'h:00 a').format(hourTime);

              return ListTile(
                dense: true,
                leading: Container(
                  width: 48,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hourStr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF667eea),
                    ),
                  ),
                ),
                title: Text(
                  '$motionEvents motion events • $deviceCount device${deviceCount != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  'Avg movement: $movement',
                  style: const TextStyle(fontSize: 11),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 60) return const Color(0xFF3B82F6);
    if (score >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}
