import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_detail_page.dart';
import 'scan_devices_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDevices();
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
          .select('device_id, location_name, device_status, last_seen, operational_mode')
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
    final houseName = widget.house['name'] as String;

    return Scaffold(
      appBar: AppBar(
        title: Text(houseName),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
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
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          return _buildDeviceCard(device);
                        },
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
    final status = device['device_status'] as String? ?? 'unknown';
    final mode = device['operational_mode'] as String? ?? 'unknown';
    final lastMotion = device['last_motion_time'] as String?;

    // Status color
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'inactive':
        statusColor = Colors.grey;
        statusIcon = Icons.remove_circle;
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.help;
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
            Text(
              'ID: $deviceId',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    mode.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
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
