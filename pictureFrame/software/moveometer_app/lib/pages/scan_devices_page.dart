import 'dart:async';
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
  Timer? _periodicScanTimer;

  @override
  void initState() {
    super.initState();
    // Wait for Bluetooth adapter to be ready before scanning
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    // Wait for Bluetooth adapter to be ready (especially important on iOS)
    try {
      // Wait up to 10 seconds for Bluetooth to be ready
      await for (final state in FlutterBluePlus.adapterState.timeout(
        const Duration(seconds: 10),
      )) {
        if (state == BluetoothAdapterState.on) {
          // Bluetooth is ready, start scanning
          if (mounted) {
            _startPeriodicScanning();
          }
          break;
        } else if (state == BluetoothAdapterState.off ||
            state == BluetoothAdapterState.unavailable) {
          // Bluetooth is off, show error
          if (mounted) {
            setState(() {
              _errorMessage = 'Bluetooth is turned off. Please turn on Bluetooth in Settings.';
            });
          }
          break;
        } else if (state == BluetoothAdapterState.unauthorized) {
          // No permission
          if (mounted) {
            setState(() {
              _errorMessage = 'Bluetooth access denied. Please enable Bluetooth permissions in Settings.';
            });
          }
          break;
        }
        // Otherwise state is 'unknown' or 'turningOn' - keep waiting
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      // Timeout or error - try scanning anyway
      if (mounted) {
        _startPeriodicScanning();
      }
    }
  }

  @override
  void dispose() {
    _periodicScanTimer?.cancel();
    _bleService.stopScan();
    super.dispose();
  }

  void _startPeriodicScanning() {
    // Start first scan immediately
    _startScan();

    // Then scan every 10 seconds (5 second scan + 5 second pause)
    _periodicScanTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _startScan();
      } else {
        timer.cancel();
      }
    });
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

      // Check if Bluetooth is on (with retry for initialization)
      BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;

      // Try up to 3 times with delays to allow Bluetooth to initialize
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          adapterState = await FlutterBluePlus.adapterState.first.timeout(
            const Duration(seconds: 2),
          );

          if (adapterState == BluetoothAdapterState.on) {
            break; // Bluetooth is ready
          } else if (adapterState == BluetoothAdapterState.turningOn) {
            // Wait for it to finish turning on
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          } else if (adapterState == BluetoothAdapterState.unknown) {
            // Still initializing, wait and retry
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          } else {
            // Off, unavailable, or unauthorized - don't retry
            break;
          }
        } catch (e) {
          // Timeout or error
          if (attempt < 2) {
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          }
        }
      }

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

      // If state is still unknown after retries, don't proceed
      if (adapterState == BluetoothAdapterState.unknown) {
        throw Exception(
          'Bluetooth is initializing. Please wait a moment and try again.',
        );
      }

      // Stop any existing scan (only if actually scanning)
      try {
        if (await FlutterBluePlus.isScanning.first) {
          await FlutterBluePlus.stopScan();
        }
      } catch (_) {
        // Ignore errors stopping scan
      }

      // Start scanning with timeout
      bool foundAny = false;
      await for (final devices in _bleService.scanForDevices(
        timeout: const Duration(seconds: 5),
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
          // Clean up error message for display
          String errorMsg = e.toString()
              .replaceAll('Exception: ', '')
              .replaceAll('PlatformException(', '')
              .replaceAll(')', '');

          // Make common errors more user-friendly
          if (errorMsg.toLowerCase().contains('bluetooth') &&
              (errorMsg.toLowerCase().contains('must be turned on') ||
               errorMsg.toLowerCase().contains('manager'))) {
            errorMsg = 'Bluetooth is initializing. Please wait a moment...';
          }

          _errorMessage = errorMsg;
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
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
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
                            onPressed: () {
                              _periodicScanTimer?.cancel();
                              _startPeriodicScanning();
                            },
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
                            // Stop periodic scanning before navigating
                            _periodicScanTimer?.cancel();
                            _bleService.stopScan();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WiFiConfigPage(
                                  device: discoveredDevice.device,
                                  deviceName: discoveredDevice.name,
                                ),
                              ),
                            ).then((_) {
                              // Restart scanning when returning from WiFi config page
                              if (mounted) {
                                _startPeriodicScanning();
                              }
                            });
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
