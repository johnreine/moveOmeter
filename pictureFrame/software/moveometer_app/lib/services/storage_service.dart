import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for secure credential storage using iOS Keychain / Android Keystore
class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Storage keys
  static const _emailKey = 'user_email';
  static const _passwordKey = 'user_password';

  /// Save login credentials securely
  /// iOS: Stored in Keychain with first_unlock accessibility
  /// Android: Stored in EncryptedSharedPreferences with AES-256
  static Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
  }

  /// Retrieve saved credentials
  /// Returns map with 'email' and 'password' keys
  /// Values will be null if not previously saved
  static Future<Map<String, String?>> getCredentials() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    return {'email': email, 'password': password};
  }

  /// Check if credentials exist in secure storage
  static Future<bool> hasCredentials() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    return email != null && password != null;
  }

  /// Clear all saved credentials (call on logout)
  static Future<void> clearCredentials() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }

  /// Clear all secure storage (use with caution)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
