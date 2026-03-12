import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceSettingsPage extends StatefulWidget {
  final Map<String, dynamic> device;

  const DeviceSettingsPage({super.key, required this.device});

  @override
  State<DeviceSettingsPage> createState() => _DeviceSettingsPageState();
}

class _DeviceSettingsPageState extends State<DeviceSettingsPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  late TextEditingController _locationNameController;

  // Human Detection Thresholds
  late TextEditingController _seatedDistanceController;
  late TextEditingController _motionDistanceController;

  // Fall Detection Timing
  late TextEditingController _fallTimeController;
  late TextEditingController _residenceTimeController;
  late bool _residenceSwitch;
  late int _fallSensitivity;

  // Sampling Rates
  late TextEditingController _fallIntervalController;
  late TextEditingController _sleepIntervalController;
  late TextEditingController _configCheckIntervalController;
  late TextEditingController _otaCheckIntervalController;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current values
    _locationNameController = TextEditingController(
      text: widget.device['location_name'] as String? ?? '',
    );

    _seatedDistanceController = TextEditingController(
      text: (widget.device['seated_distance_threshold_cm'] ?? 100).toString(),
    );
    _motionDistanceController = TextEditingController(
      text: (widget.device['motion_distance_threshold_cm'] ?? 150).toString(),
    );

    _fallTimeController = TextEditingController(
      text: (widget.device['fall_time_sec'] ?? 5).toString(),
    );
    _residenceTimeController = TextEditingController(
      text: (widget.device['residence_time_sec'] ?? 30).toString(),
    );
    _residenceSwitch = widget.device['residence_switch'] as bool? ?? true;
    _fallSensitivity = widget.device['fall_sensitivity'] as int? ?? 3;

    _fallIntervalController = TextEditingController(
      text: (widget.device['fall_detection_interval_ms'] ?? 20000).toString(),
    );
    _sleepIntervalController = TextEditingController(
      text: (widget.device['sleep_mode_interval_ms'] ?? 20000).toString(),
    );
    _configCheckIntervalController = TextEditingController(
      text: (widget.device['config_check_interval_ms'] ?? 20000).toString(),
    );
    _otaCheckIntervalController = TextEditingController(
      text: (widget.device['ota_check_interval_ms'] ?? 3600000).toString(),
    );
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    _seatedDistanceController.dispose();
    _motionDistanceController.dispose();
    _fallTimeController.dispose();
    _residenceTimeController.dispose();
    _fallIntervalController.dispose();
    _sleepIntervalController.dispose();
    _configCheckIntervalController.dispose();
    _otaCheckIntervalController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final deviceId = widget.device['device_id'] as String;

      await _supabase.from('moveometers').update({
        'location_name': _locationNameController.text.trim(),
        'seated_distance_threshold_cm': int.parse(_seatedDistanceController.text),
        'motion_distance_threshold_cm': int.parse(_motionDistanceController.text),
        'fall_time_sec': int.parse(_fallTimeController.text),
        'residence_time_sec': int.parse(_residenceTimeController.text),
        'residence_switch': _residenceSwitch,
        'fall_sensitivity': _fallSensitivity,
        'fall_detection_interval_ms': int.parse(_fallIntervalController.text),
        'sleep_mode_interval_ms': int.parse(_sleepIntervalController.text),
        'config_check_interval_ms': int.parse(_configCheckIntervalController.text),
        'ota_check_interval_ms': int.parse(_otaCheckIntervalController.text),
      }).eq('device_id', deviceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate settings were changed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Settings'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveSettings,
              tooltip: 'Save',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Device ID Section (Read-only)
            _buildSectionHeader('Device Information'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: widget.device['device_id'] as String,
                      decoration: const InputDecoration(
                        labelText: 'Device ID',
                        prefixIcon: Icon(Icons.fingerprint),
                        border: OutlineInputBorder(),
                        enabled: false,
                      ),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationNameController,
                      decoration: const InputDecoration(
                        labelText: 'Room Name',
                        hintText: 'e.g., Bedroom, Living Room',
                        prefixIcon: Icon(Icons.room),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Room name is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Human Detection Thresholds Section
            _buildSectionHeader('Human Detection Thresholds'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _seatedDistanceController,
                      decoration: const InputDecoration(
                        labelText: 'Seated Distance Threshold (cm)',
                        hintText: '100',
                        helperText: 'Max distance to detect seated persons',
                        prefixIcon: Icon(Icons.chair),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final val = int.tryParse(value);
                        if (val == null || val < 0 || val > 500) {
                          return 'Must be between 0 and 500';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _motionDistanceController,
                      decoration: const InputDecoration(
                        labelText: 'Motion Distance Threshold (cm)',
                        hintText: '150',
                        helperText: 'Max distance to detect moving persons',
                        prefixIcon: Icon(Icons.directions_walk),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final val = int.tryParse(value);
                        if (val == null || val < 0 || val > 500) {
                          return 'Must be between 0 and 500';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Fall Detection Timing Section
            _buildSectionHeader('Fall Detection Timing'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Fall Sensitivity Slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, color: Color(0xFF667eea)),
                            const SizedBox(width: 8),
                            Text(
                              'Fall Sensitivity: $_fallSensitivity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _fallSensitivity.toDouble(),
                          min: 0,
                          max: 3,
                          divisions: 3,
                          label: _getSensitivityLabel(_fallSensitivity),
                          onChanged: (value) {
                            setState(() => _fallSensitivity = value.toInt());
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('0 (Least)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              Text('3 (Most)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fallTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Fall Time Delay (seconds)',
                        hintText: '5',
                        helperText: 'Delay before reporting fall (1-30s)',
                        prefixIcon: Icon(Icons.timer),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final val = int.tryParse(value);
                        if (val == null || val < 1 || val > 30) {
                          return 'Must be between 1 and 30';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _residenceTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Residence Time (seconds)',
                        hintText: '30',
                        helperText: 'Motionless time before floor alert (10-600s)',
                        prefixIcon: Icon(Icons.access_time),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final val = int.tryParse(value);
                        if (val == null || val < 10 || val > 600) {
                          return 'Must be between 10 and 600';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Enable Residence Detection'),
                      subtitle: const Text('Detect if lying on floor motionless'),
                      value: _residenceSwitch,
                      onChanged: (value) {
                        setState(() => _residenceSwitch = value);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Sampling Rates Section
            _buildSectionHeader('Sampling Intervals'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _fallIntervalController,
                      decoration: const InputDecoration(
                        labelText: 'Fall Detection Interval (ms)',
                        hintText: '20000',
                        helperText: 'Data collection rate in fall mode',
                        prefixIcon: Icon(Icons.speed),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final val = int.tryParse(value);
                        if (val == null || val < 1000) {
                          return 'Must be at least 1000ms';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sleepIntervalController,
                      decoration: const InputDecoration(
                        labelText: 'Sleep Mode Interval (ms)',
                        hintText: '20000',
                        helperText: 'Data collection rate in sleep mode',
                        prefixIcon: Icon(Icons.bedtime),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final val = int.tryParse(value);
                        if (val == null || val < 1000) {
                          return 'Must be at least 1000ms';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _configCheckIntervalController,
                      decoration: const InputDecoration(
                        labelText: 'Config Check Interval (ms)',
                        hintText: '20000',
                        helperText: 'How often to check for config updates',
                        prefixIcon: Icon(Icons.settings_suggest),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final val = int.tryParse(value);
                        if (val == null || val < 1000) {
                          return 'Must be at least 1000ms';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _otaCheckIntervalController,
                      decoration: const InputDecoration(
                        labelText: 'OTA Check Interval (ms)',
                        hintText: '3600000',
                        helperText: 'How often to check for firmware updates',
                        prefixIcon: Icon(Icons.system_update),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final val = int.tryParse(value);
                        if (val == null || val < 60000) {
                          return 'Must be at least 60000ms (1 min)';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getSensitivityLabel(int sensitivity) {
    switch (sensitivity) {
      case 0:
        return 'Very Low';
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      default:
        return 'Medium';
    }
  }
}
