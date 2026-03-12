import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Service for managing app settings
class SettingsService {
  static const String _timeFormatKey = 'time_format_24h';
  static const String _themeModeKey = 'theme_mode';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _defaultTimeRangeKey = 'default_time_range';

  /// Get time format preference (true = 24h, false = 12h)
  Future<bool> getUse24HourFormat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_timeFormatKey) ?? false; // Default to 12h
  }

  /// Set time format preference
  Future<void> setUse24HourFormat(bool use24h) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timeFormatKey, use24h);
  }

  /// Get theme mode preference
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_themeModeKey) ?? 'system';
    switch (themeModeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Set theme mode preference
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      default:
        modeString = 'system';
    }
    await prefs.setString(_themeModeKey, modeString);
  }

  /// Get notifications enabled preference
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true; // Default to enabled
  }

  /// Set notifications enabled preference
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
  }

  /// Get default time range for charts (in days)
  Future<int> getDefaultTimeRange() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultTimeRangeKey) ?? 7; // Default to 7 days
  }

  /// Set default time range for charts (in days)
  Future<void> setDefaultTimeRange(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultTimeRangeKey, days);
  }
}
