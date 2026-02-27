import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_provisioning_service.dart';
import 'wifi_config_page.dart';

class ScanDevicesPage extends StatefulWidget {
  const ScanDevicesPage({super.key});

  @override
  State<ScanDevicesPage> createState() => _ScanDevicesPageState();
}

class _ScanDevicesPageState extends State<ScanDevicesPage> {
  final _bleService = BLEProvisioningService();
  final List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _bleService.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _errorMessage = null;
      _isScanning = true;
    });

    try {
      // Check Bluetooth permissions (iOS and Android)
      try {
        if (await Permission.bluetoothScan.isDenied) {
          final status = await Permission.bluetoothScan.request();
          if (status.isDenied) {
            throw Exception(
              'Bluetooth scan permission required. Please grant permission in Settings.',
            );
          }
          if (status.isPermanentlyDenied) {
            throw Exception(
              'Bluetooth permission permanently denied. Please enable it in Settings > moveOmeter.',
            );
          }
        }

        if (await Permission.bluetoothConnect.isDenied) {
          final status = await Permission.bluetoothConnect.request();
          if (status.isDenied) {
            throw Exception(
              'Bluetooth connect permission required. Please grant permission in Settings.',
            );
          }
          if (status.isPermanentlyDenied) {
            throw Exception(
              'Bluetooth permission permanently denied. Please enable it in Settings > moveOmeter.',
            );
          }
        }
      } catch (e) {
        // On iOS < 13, permission_handler may throw. Ignore and continue.
        if (!e.toString().contains('permission')) {
          rethrow;
        }
      }

      // Check if Bluetooth is supported
      if (!await FlutterBluePlus.isSupported) {
        throw Exception(
          'Bluetooth Low Energy is not supported on this device.',
        );
      }

      // Check if Bluetooth is on
      final adapterState = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => BluetoothAdapterState.unknown,
      );

      if (adapterState == BluetoothAdapterState.off ||
          adapterState == BluetoothAdapterState.unavailable) {
        throw Exception(
          'Bluetooth is turned off. Please turn on Bluetooth in Settings and try again.',
        );
      }

      if (adapterState == BluetoothAdapterState.unauthorized) {
        throw Exception(
          'Bluetooth access is not authorized. Please enable Bluetooth permissions in Settings.',
        );
      }

      if (adapterState == BluetoothAdapterState.unknown) {
        throw Exception(
          'Unable to determine Bluetooth status. Please ensure Bluetooth is enabled.',
        );
      }

      // Stop any existing scan
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Ignore errors stopping scan
      }

      // Start scanning with timeout
      bool foundAny = false;
      await for (final devices in _bleService.scanForDevices(
        timeout: const Duration(seconds: 15),
      )) {
        if (mounted) {
          setState(() {
            _devices.clear();
            _devices.addAll(devices);
          });
          if (devices.isNotEmpty) {
            foundAny = true;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
          if (!foundAny) {
            _errorMessage = 'No moveOmeter devices found nearby. '
                'Make sure the device is powered on and in provisioning mode '
                '(blue blinking LED).';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan for Devices'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Scanning indicator
          if (_isScanning)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF667eea).withOpacity(0.1),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Scanning for devices...'),
                  ),
                ],
              ),
            ),

          // Error message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning
                              ? 'Looking for devices...'
                              : 'No devices found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (!_isScanning) ...[
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _startScan,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Scan Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final discoveredDevice = _devices[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bluetooth,
                              color: Color(0xFF667eea),
                            ),
                          ),
                          title: Text(
                            discoveredDevice.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Tap to configure WiFi',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WiFiConfigPage(
                                  device: discoveredDevice.device,
                                  deviceName: discoveredDevice.name,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
