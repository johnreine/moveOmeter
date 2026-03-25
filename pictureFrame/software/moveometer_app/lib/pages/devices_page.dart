import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_detail_page.dart';
import 'scan_devices_page.dart';
import 'house_settings_page.dart';
import '../widgets/house_summary_card.dart';

final supabase = Supabase.instance.client;

class DevicesPage extends StatefulWidget {
  final Map<String, dynamic> house;

  const DevicesPage({super.key, required this.house});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _houseName = '';

  @override
  void initState() {
    super.initState();
    _houseName = widget.house['name'] as String;
    _loadDevices();
  }

  Future<void> _refreshHouseData() async {
    try {
      final houseId = widget.house['id'];
      final response = await supabase
          .from('houses')
          .select('name')
          .eq('id', houseId)
          .single();

      if (mounted) {
        setState(() {
          _houseName = response['name'] as String;
        });
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final houseId = widget.house['id'];

      // Get all devices in this house
      final response = await supabase
          .from('moveometers')
          .select('device_id, location_name, device_status, last_seen, operational_mode, connection_status, seconds_since_last_data, connection_quality_score')
          .eq('house_id', houseId)
          .order('location_name');

      final devices = List<Map<String, dynamic>>.from(response);

      // For each device, get the last motion time from daily metrics
      for (var device in devices) {
        try {
          // Try to get today's last motion time from daily_aggregates
          final today = DateTime.now();
          final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

          final metrics = await supabase
              .from('daily_aggregates')
              .select('last_motion_time')
              .eq('device_id', device['device_id'])
              .eq('date', dateStr)
              .maybeSingle();

          if (metrics != null && metrics['last_motion_time'] != null) {
            device['last_motion_time'] = metrics['last_motion_time'];
          } else {
            // Fallback: get the most recent motion from sensor_data where there was actual movement
            final sensorData = await supabase
                .from('sensor_data')
                .select('timestamp')
                .eq('device_id', device['device_id'])
                .gt('body_movement', 0)
                .order('timestamp', ascending: false)
                .limit(1)
                .maybeSingle();

            if (sensorData != null) {
              device['last_motion_time'] = sensorData['timestamp'];
            }
          }
        } catch (e) {
          // If no data found, leave last_motion_time as null
        }
      }

      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_houseName),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HouseSettingsPage(house: widget.house),
                ),
              );
              // Reload house data if settings were changed
              if (result == true) {
                await _refreshHouseData();
              }
            },
            tooltip: 'House Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading devices',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _loadDevices,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sensors, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No devices in this house',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add moveOmeters to start monitoring.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadDevices,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // House Summary Card
                          HouseSummaryCard(house: widget.house),

                          // Device List
                          ..._devices.map((device) => _buildDeviceCard(device)).toList(),
                        ],
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ScanDevicesPage(),
            ),
          ).then((_) => _loadDevices()); // Reload devices when returning
        },
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final deviceId = device['device_id'] as String;
    final locationName = device['location_name'] as String? ?? 'Unknown Location';
    final deviceStatus = device['device_status'] as String? ?? 'unknown';
    final connectionStatus = device['connection_status'] as String? ?? 'unknown';
    final mode = device['operational_mode'] as String? ?? 'unknown';
    final lastMotion = device['last_motion_time'] as String?;
    final secondsSinceData = device['seconds_since_last_data'] as int? ?? 0;

    // Connection status color and icon (shows real-time online/offline)
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (connectionStatus) {
      case 'online':
        statusColor = Colors.green;
        statusIcon = Icons.wifi;
        statusText = 'Online';
        break;
      case 'stale':
        statusColor = Colors.orange;
        statusIcon = Icons.wifi_off;
        statusText = 'Stale';
        break;
      case 'offline':
        statusColor = Colors.red;
        statusIcon = Icons.cloud_off;
        statusText = 'Offline';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
    }

    // If device is inactive (not deployed), override to grey
    if (deviceStatus != 'active') {
      statusColor = Colors.grey;
      statusIcon = Icons.remove_circle;
      statusText = 'Inactive';
    }

    // Format last motion
    String lastMotionText = 'No data';
    if (lastMotion != null) {
      try {
        final lastMotionDate = DateTime.parse(lastMotion);
        final now = DateTime.now();
        final difference = now.difference(lastMotionDate);

        if (difference.inMinutes < 1) {
          lastMotionText = 'Just now';
        } else if (difference.inHours < 1) {
          lastMotionText = '${difference.inMinutes}m ago';
        } else if (difference.inDays < 1) {
          lastMotionText = '${difference.inHours}h ago';
        } else {
          lastMotionText = '${difference.inDays}d ago';
        }
      } catch (e) {
        lastMotionText = 'Unknown';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.sensors,
            color: Colors.white,
            size: 32,
          ),
        ),
        title: Text(
          locationName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Last motion: $lastMotionText',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceDetailPage(device: device),
            ),
          );
        },
      ),
    );
  }
}
