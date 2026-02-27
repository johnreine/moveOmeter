import 'dart:convert';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE Provisioning Service for configuring WiFi on moveOmeter devices
///
/// Matches the firmware UUIDs and protocol defined in ble_provisioning.h
class BLEProvisioningService {
  // UUIDs must match firmware (ble_provisioning.h)
  static const String serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  /// Scan for nearby moveOmeter devices
  ///
  /// Returns a stream of discovered devices.
  /// Filters for devices advertising our service UUID.
  Stream<List<BluetoothDevice>> scanForDevices({Duration timeout = const Duration(seconds: 10)}) async* {
    final devices = <String, BluetoothDevice>{};

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [Guid(serviceUUID)],
    );

    // Listen to scan results
    await for (final results in FlutterBluePlus.scanResults) {
      for (final result in results) {
        // Filter by name prefix "moveOmeter-"
        if (result.device.platformName.startsWith('moveOmeter-')) {
          devices[result.device.remoteId.toString()] = result.device;
        }
      }
      yield devices.values.toList();
    }

    // Stop scanning when stream closes
    await FlutterBluePlus.stopScan();
  }

  /// Provision a device with WiFi credentials
  ///
  /// Connects to device, sends credentials via BLE, waits for response.
  /// Throws exception on error with detailed error messages.
  Future<void> provisionDevice({
    required BluetoothDevice device,
    required String ssid,
    required String password,
  }) async {
    BluetoothCharacteristic? targetCharacteristic;
    StreamSubscription? subscription;

    try {
      // Validate inputs
      if (ssid.trim().isEmpty) {
        throw Exception('WiFi network name cannot be empty');
      }
      if (ssid.length > 32) {
        throw Exception('WiFi network name too long (max 32 characters)');
      }
      if (password.length < 8) {
        throw Exception('WiFi password must be at least 8 characters');
      }
      if (password.length > 63) {
        throw Exception('WiFi password too long (max 63 characters)');
      }

      // Check if already connected
      final connectedDevices = FlutterBluePlus.connectedDevices;
      if (connectedDevices.any((d) => d.remoteId == device.remoteId)) {
        // Already connected, disconnect first to start fresh
        try {
          await device.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (_) {
          // Ignore disconnect errors
        }
      }

      // Connect to device with retry logic
      int connectAttempts = 0;
      const maxConnectAttempts = 3;
      while (connectAttempts < maxConnectAttempts) {
        try {
          await device.connect(
            timeout: const Duration(seconds: 15),
            autoConnect: false,
          );
          break;
        } catch (e) {
          connectAttempts++;
          if (connectAttempts >= maxConnectAttempts) {
            throw Exception(
              'Failed to connect to device after $maxConnectAttempts attempts. '
              'Make sure the device is nearby and not already connected to another phone.',
            );
          }
          // Wait before retry
          await Future.delayed(Duration(seconds: connectAttempts));
        }
      }

      // Verify connection
      await Future.delayed(const Duration(milliseconds: 500));
      final connectionState = await device.connectionState.first;
      if (connectionState != BluetoothConnectionState.connected) {
        throw Exception('Connection failed - device is not connected');
      }

      // Discover services with timeout
      List<BluetoothService> services;
      try {
        services = await device.discoverServices().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception(
            'Service discovery timeout. The device may be unresponsive.',
          ),
        );
      } catch (e) {
        throw Exception('Failed to discover services: ${e.toString()}');
      }

      if (services.isEmpty) {
        throw Exception(
          'No services found on device. This may not be a valid moveOmeter device.',
        );
      }

      // Find our service and characteristic
      for (final service in services) {
        if (service.serviceUuid.toString().toLowerCase() == serviceUUID.toLowerCase()) {
          for (final char in service.characteristics) {
            if (char.characteristicUuid.toString().toLowerCase() ==
                characteristicUUID.toLowerCase()) {
              targetCharacteristic = char;
              break;
            }
          }
        }
      }

      if (targetCharacteristic == null) {
        throw Exception(
          'Provisioning service not found. This device may be running old firmware. '
          'Please update the device firmware and try again.',
        );
      }

      // Verify characteristic properties
      if (!targetCharacteristic.properties.write) {
        throw Exception('Device does not support WiFi provisioning (write not supported)');
      }

      // Enable notifications to receive response
      try {
        if (targetCharacteristic.properties.notify) {
          await targetCharacteristic.setNotifyValue(true);
        }
      } catch (e) {
        throw Exception('Failed to enable notifications: ${e.toString()}');
      }

      // Create credentials JSON
      final credentials = {
        'ssid': ssid.trim(),
        'password': password,
      };
      final jsonString = jsonEncode(credentials);
      final bytes = utf8.encode(jsonString);

      // Check payload size (BLE MTU is typically 512 bytes, be conservative)
      if (bytes.length > 200) {
        throw Exception(
          'Credentials too long. Please use a shorter network name or password.',
        );
      }

      // Set up notification listener for response
      final responseCompleter = Completer<Map<String, dynamic>>();
      subscription = targetCharacteristic.onValueReceived.listen(
        (value) {
          if (responseCompleter.isCompleted) return;
          try {
            final responseString = utf8.decode(value);
            final response = jsonDecode(responseString) as Map<String, dynamic>;
            responseCompleter.complete(response);
          } catch (e) {
            if (!responseCompleter.isCompleted) {
              responseCompleter.completeError(
                'Device sent invalid response. Raw: ${String.fromCharCodes(value)}',
              );
            }
          }
        },
        onError: (error) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError('BLE notification error: $error');
          }
        },
      );

      // Write credentials with retry
      int writeAttempts = 0;
      const maxWriteAttempts = 3;
      while (writeAttempts < maxWriteAttempts) {
        try {
          await targetCharacteristic.write(
            bytes,
            withoutResponse: false,
            timeout: 5,
          );
          break;
        } catch (e) {
          writeAttempts++;
          if (writeAttempts >= maxWriteAttempts) {
            throw Exception('Failed to send credentials after $maxWriteAttempts attempts');
          }
          await Future.delayed(Duration(milliseconds: 500 * writeAttempts));
        }
      }

      // Wait for response (with timeout)
      Map<String, dynamic> response;
      try {
        response = await responseCompleter.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception(
            'Device did not respond within 15 seconds. '
            'The device may have rebooted successfully, or there was an error. '
            'Check if the device appears in your devices list.',
          ),
        );
      } catch (e) {
        // If timeout, it might actually be success (device rebooted before responding)
        rethrow;
      }

      // Check response status
      if (response['status'] == 'error') {
        final errorMsg = response['message'] ?? 'Unknown error from device';
        throw Exception('Device error: $errorMsg');
      }

      if (response['status'] != 'success') {
        throw Exception(
          'Unexpected response from device: ${response['status']}. '
          'Expected "success" or "error".',
        );
      }

      // Success! Device will reboot and connect to WiFi
    } on Exception {
      // Re-throw Exception types as-is
      rethrow;
    } catch (e) {
      // Wrap other errors in Exception with context
      throw Exception('Provisioning failed: ${e.toString()}');
    } finally {
      // Clean up subscription
      await subscription?.cancel();

      // Disconnect with timeout
      try {
        await device.disconnect().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // Ignore timeout on disconnect
          },
        );
      } catch (_) {
        // Ignore all disconnect errors
      }
    }
  }

  /// Stop any active BLE scan
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}
