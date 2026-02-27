import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _ssidFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
            const Text(
              'Enter your WiFi network credentials to configure the device:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 24),

            // SSID field
            TextFormField(
              controller: _ssidController,
              focusNode: _ssidFocusNode,
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
                labelText: 'WiFi Password',
                hintText: 'Enter password',
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
                if (value == null || value.isEmpty) {
                  return 'Please enter password';
                }
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
