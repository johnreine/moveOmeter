import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../pages/house_day_detail_page.dart';

class HouseSummaryCard extends StatefulWidget {
  final Map<String, dynamic> house;

  const HouseSummaryCard({super.key, required this.house});

  @override
  State<HouseSummaryCard> createState() => _HouseSummaryCardState();
}

class _HouseSummaryCardState extends State<HouseSummaryCard> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, dynamic>? _houseSummary;
  List<Map<String, dynamic>> _dailyHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHouseSummary();
  }

  Future<void> _loadHouseSummary() async {
    setState(() => _isLoading = true);

    try {
      final houseId = widget.house['id'];
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Query house-level aggregate directly from database (NO client-side calculation)
      final response = await _supabase
          .from('daily_aggregates')
          .select('*')
          .eq('house_id', houseId)
          .eq('date', dateStr)
          .maybeSingle();

      if (response == null) {
        // No house-level data yet - count devices for display
        final devices = await _supabase
            .from('moveometers')
            .select('device_id')
            .eq('house_id', houseId)
            .eq('device_status', 'active');

        setState(() {
          _houseSummary = {
            'motion_score': 0,
            'total_active_minutes': 0,
            'last_motion_time': null,
            'device_count': devices.length,
          };
        });
      } else {
        // Use server-calculated house-level metrics
        setState(() {
          _houseSummary = {
            'motion_score': response['motion_score'] as int? ?? 0,
            'total_active_minutes': response['total_active_minutes'] as int? ?? 0,
            'last_motion_time': response['last_motion_time'] as String?,
            'device_count': 1, // Will be replaced with actual device count if needed
          };
        });

        // Get device count for display
        final devices = await _supabase
            .from('moveometers')
            .select('device_id')
            .eq('house_id', houseId)
            .eq('device_status', 'active');

        setState(() {
          _houseSummary!['device_count'] = devices.length;
        });
      }

      // Load last 7 days of house-level history
      await _loadDailyHistory(houseId);

    } catch (e) {
      print('Error loading house summary: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDailyHistory(String houseId) async {
    try {
      final List<Map<String, dynamic>> history = [];

      // Query house-level aggregates for last 7 days (NO client-side calculation)
      final startDate = DateTime.now().subtract(const Duration(days: 6));
      final startDateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('daily_aggregates')
          .select('*')
          .eq('house_id', houseId)
          .gte('date', startDateStr)
          .order('date', ascending: false);

      // Convert database records to display format
      for (var record in response) {
        final dateStr = record['date'] as String;
        final date = DateTime.parse(dateStr);

        final firstMotionStr = record['first_motion_time'] as String?;
        final lastMotionStr = record['last_motion_time'] as String?;

        history.add({
          'date': date,
          'motion_score': record['motion_score'] as int? ?? 0,
          'total_active_minutes': record['total_active_minutes'] as int? ?? 0,
          'first_motion_time': firstMotionStr != null ? DateTime.parse(firstMotionStr) : null,
          'last_motion_time': lastMotionStr != null ? DateTime.parse(lastMotionStr) : null,
          'device_count': 0, // Not used in house-level view
        });
      }

      setState(() {
        _dailyHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading daily history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        margin: EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_houseSummary == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // House Summary Header
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
          child: Text(
            'HOUSE SUMMARY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Today's Summary Card
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 3,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HouseDayDetailPage(
                    house: widget.house,
                    date: DateTime.now(),
                    metrics: _houseSummary!,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.home, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Today's Activity",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_houseSummary!['device_count']} device${_houseSummary!['device_count'] != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metrics Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          'Motion Score',
                          '${_houseSummary!['motion_score']}',
                          Icons.show_chart,
                          _getScoreColor(_houseSummary!['motion_score']),
                        ),
                      ),
                      Expanded(
                        child: _buildMetricItem(
                          'Active Time',
                          '${_houseSummary!['total_active_minutes']} min',
                          Icons.timer,
                          const Color(0xFF667eea),
                        ),
                      ),
                      Expanded(
                        child: _buildMetricItem(
                          'Last Motion',
                          _formatLastMotion(_houseSummary!['last_motion_time']),
                          Icons.access_time,
                          Colors.grey[700]!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Daily History Section
        if (_dailyHistory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
            child: Text(
              'DAILY HISTORY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...(_dailyHistory.map((day) => _buildDayCard(day)).toList()),
        ],

        // Divider before device list
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
          child: Text(
            'DEVICES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
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
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final date = day['date'] as DateTime;
    final isToday = DateTime.now().difference(date).inDays == 0;
    final motionScore = day['motion_score'] as int;
    final activeMinutes = day['total_active_minutes'] as int;
    final firstMotion = day['first_motion_time'] as DateTime?;
    final lastMotion = day['last_motion_time'] as DateTime?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getScoreColor(motionScore).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('MMM').format(date).toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('d').format(date),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(motionScore),
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            if (isToday)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              DateFormat('EEEE').format(date),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        subtitle: Text(
          'Score: $motionScore • ${activeMinutes}min active',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (firstMotion != null)
              Text(
                DateFormat('h:mm a').format(firstMotion),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            if (lastMotion != null)
              Text(
                DateFormat('h:mm a').format(lastMotion),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HouseDayDetailPage(
                house: widget.house,
                date: date,
                metrics: day,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF22C55E); // Green
    if (score >= 60) return const Color(0xFF3B82F6); // Blue
    if (score >= 40) return const Color(0xFFF59E0B); // Orange
    return const Color(0xFFEF4444); // Red
  }

  String _formatLastMotion(String? lastMotionStr) {
    if (lastMotionStr == null) return 'No data';

    try {
      final lastMotion = DateTime.parse(lastMotionStr);
      final now = DateTime.now();
      final difference = now.difference(lastMotion);

      if (difference.inMinutes < 1) return 'Now';
      if (difference.inHours < 1) return '${difference.inMinutes}m';
      if (difference.inDays < 1) return '${difference.inHours}h';
      return '${difference.inDays}d';
    } catch (e) {
      return 'Unknown';
    }
  }
}
