import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_provisioning_service.dart';

class WiFiConfigPage extends StatefulWidget {
  final BluetoothDevice device;
  final String deviceName;

  const WiFiConfigPage({
    super.key,
    required this.device,
    required this.deviceName,
  });

  @override
  State<WiFiConfigPage> createState() => _WiFiConfigPageState();
}

class _WiFiConfigPageState extends State<WiFiConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ssidFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _bleService = BLEProvisioningService();

  bool _isProvisioning = false;
  bool _obscurePassword = true;
  bool _isScanning = false;
  List<WiFiAccessPoint> _availableNetworks = [];
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _scanForNetworks();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _ssidFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _scanForNetworks() async {
    // iOS doesn't allow WiFi network scanning due to privacy restrictions
    // Skip scanning on iOS and let user enter SSID manually
    if (Platform.isIOS) {
      setState(() {
        _isScanning = false;
        _scanError = null;
        _availableNetworks = [];
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    try {
      // Request location permission (required for WiFi scanning on Android)
      PermissionStatus status = await Permission.location.status;

      // If not granted, request it
      if (!status.isGranted && !status.isLimited) {
        status = await Permission.location.request();
      }

      // Check if we have sufficient permission
      if (!status.isGranted && !status.isLimited) {
        setState(() {
          _scanError = 'Location permission required to scan for WiFi networks. Please enable in Settings.';
          _isScanning = false;
        });
        return;
      }

      // Check if WiFi scan is supported
      final canGetScannedResults = await WiFiScan.instance.canGetScannedResults();
      if (canGetScannedResults != CanGetScannedResults.yes) {
        setState(() {
          _scanError = 'WiFi scanning not available on this device';
          _isScanning = false;
        });
        return;
      }

      // Start WiFi scan
      final canStartScan = await WiFiScan.instance.canStartScan();
      if (canStartScan == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        // Wait a bit for scan to complete
        await Future.delayed(const Duration(seconds: 2));
      }

      // Get scan results
      final results = await WiFiScan.instance.getScannedResults();

      // Filter and sort by signal strength (stronger signal = higher level)
      final uniqueNetworks = <String, WiFiAccessPoint>{};
      for (final ap in results) {
        final ssid = ap.ssid;
        if (ssid.isNotEmpty) {
          // Keep the network with the strongest signal for duplicate SSIDs
          if (!uniqueNetworks.containsKey(ssid) ||
              ap.level > uniqueNetworks[ssid]!.level) {
            uniqueNetworks[ssid] = ap;
          }
        }
      }

      final sortedNetworks = uniqueNetworks.values.toList()
        ..sort((a, b) => b.level.compareTo(a.level)); // Descending order (strongest first)

      setState(() {
        _availableNetworks = sortedNetworks;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _scanError = 'Failed to scan for networks: $e';
        _isScanning = false;
      });
    }
  }

  Map<String, dynamic> _getSignalStrength(int level) {
    // WiFi signal strength (dBm):
    // Excellent: -30 to -50
    // Good: -50 to -60
    // Fair: -60 to -70
    // Weak: -70 to -80
    // Very Weak: < -80
    if (level >= -50) {
      return {'label': 'Excellent', 'color': Colors.green[700]};
    } else if (level >= -60) {
      return {'label': 'Good', 'color': Colors.green[600]};
    } else if (level >= -70) {
      return {'label': 'Fair', 'color': Colors.orange[700]};
    } else if (level >= -80) {
      return {'label': 'Weak', 'color': Colors.orange[800]};
    } else {
      return {'label': 'Very Weak', 'color': Colors.red[700]};
    }
  }

  IconData _getWifiIcon(int level, String capabilities) {
    // Choose icon based on signal strength
    if (level >= -50) {
      return Icons.wifi;
    } else if (level >= -60) {
      return Icons.wifi_2_bar;
    } else if (level >= -70) {
      return Icons.wifi_1_bar;
    } else {
      return Icons.wifi_1_bar;
    }
  }

  Future<void> _provision() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isProvisioning = true;
    });

    try {
      // Add a small delay to let UI update
      await Future.delayed(const Duration(milliseconds: 100));

      await _bleService.provisionDevice(
        device: widget.device,
        ssid: _ssidController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 28),
                const SizedBox(width: 12),
                const Text('Success!'),
              ],
            ),
            content: const Text(
              'WiFi configured successfully!\n\n'
              'The device will reboot and connect to your network. '
              'It should appear in your devices list within 10-30 seconds.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close WiFi config page
                  Navigator.pop(context); // Close scan page
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Parse error message
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        String? suggestion;

        // Provide helpful suggestions based on error type
        if (errorMessage.contains('connect') || errorMessage.contains('Connection')) {
          suggestion = 'Make sure you\'re close to the device and try again.';
        } else if (errorMessage.contains('timeout') || errorMessage.contains('did not respond')) {
          suggestion = 'The device may have rebooted. Check your devices list to see if it appeared.';
        } else if (errorMessage.contains('permission')) {
          suggestion = 'Go to Settings > moveOmeter and enable Bluetooth permissions.';
        } else if (errorMessage.contains('service not found') || errorMessage.contains('old firmware')) {
          suggestion = 'This device may need a firmware update. Contact support.';
        } else if (errorMessage.contains('password')) {
          suggestion = 'Check that your password is correct (8-63 characters).';
        } else if (errorMessage.contains('SSID') || errorMessage.contains('network name')) {
          suggestion = 'Check that your network name is correct (1-32 characters).';
        }

        // Show error dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[600], size: 28),
                const SizedBox(width: 12),
                const Expanded(child: Text('Configuration Failed')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                if (suggestion != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 20, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Try Again'),
              ),
            ],
          ),
        );

        setState(() {
          _isProvisioning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure WiFi'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Device info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.bluetooth_connected,
                            color: Color(0xFF667eea),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Connected to:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.deviceName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Text(
              Platform.isIOS
                  ? 'Enter your WiFi network name and password:'
                  : 'Select a network or enter WiFi credentials manually:',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 16),

            // Available Networks Section (Android only)
            if (!Platform.isIOS && _isScanning)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Scanning for networks...'),
                  ],
                ),
              )
            else if (!Platform.isIOS && _scanError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, size: 20, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _scanError!,
                            style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                          ),
                        ),
                      ],
                    ),
                    if (_scanError!.contains('permission'))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await openAppSettings();
                            },
                            icon: const Icon(Icons.settings, size: 18),
                            label: const Text('Open Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else if (!Platform.isIOS && _availableNetworks.isNotEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Available Networks (${_availableNetworks.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed: _isProvisioning ? null : _scanForNetworks,
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _availableNetworks.length,
                        itemBuilder: (context, index) {
                          final network = _availableNetworks[index];
                          final signalStrength = _getSignalStrength(network.level);

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              _getWifiIcon(network.level, network.capabilities),
                              color: signalStrength['color'] as Color,
                            ),
                            title: Text(
                              network.ssid,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              signalStrength['label'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: signalStrength['color'] as Color,
                              ),
                            ),
                            trailing: network.capabilities.contains('WPA') ||
                                    network.capabilities.contains('WEP')
                                ? Icon(Icons.lock, size: 16, color: Colors.grey[600])
                                : null,
                            onTap: _isProvisioning
                                ? null
                                : () {
                                    setState(() {
                                      _ssidController.text = network.ssid;
                                    });
                                    _passwordFocusNode.requestFocus();
                                  },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            if (_availableNetworks.isNotEmpty || _scanError != null)
              const SizedBox(height: 16),

            // SSID field
            TextFormField(
              controller: _ssidController,
              focusNode: _ssidFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableInteractiveSelection: true,
              onFieldSubmitted: (_) {
                _passwordFocusNode.requestFocus();
              },
              decoration: InputDecoration(
                labelText: 'WiFi Network Name (SSID)',
                hintText: 'e.g., MyHomeNetwork',
                prefixIcon: const Icon(Icons.wifi),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter network name';
                }
                if (value.length > 32) {
                  return 'Network name too long (max 32 characters)';
                }
                return null;
              },
              enabled: !_isProvisioning,
            ),

            const SizedBox(height: 16),

            // Password field
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.visiblePassword,
              autocorrect: false,
              enableSuggestions: false,
              enableInteractiveSelection: true,
              onFieldSubmitted: (_) => !_isProvisioning ? _provision() : null,
              decoration: InputDecoration(
                labelText: 'WiFi Password (optional)',
                hintText: 'Leave blank for open networks',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                // Allow empty password for open networks
                if (value == null || value.isEmpty) {
                  return null; // Valid - open network
                }
                // If password is provided, validate length
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                if (value.length > 63) {
                  return 'Password too long (max 63 characters)';
                }
                return null;
              },
              enabled: !_isProvisioning,
            ),

            const SizedBox(height: 32),

            // Configure button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isProvisioning ? null : _provision,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProvisioning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 16),
                          Text('Configuring...'),
                        ],
                      )
                    : const Text(
                        'Configure WiFi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Help text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The device will reboot after configuration. '
                      'Make sure you\'re connected to the correct network.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
