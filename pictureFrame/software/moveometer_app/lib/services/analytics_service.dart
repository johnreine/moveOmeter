import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

/// Analytics service for tracking app usage, sessions, and user actions
class AnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _sessionId;
  String? _userId;
  DateTime? _sessionStartTime;
  int _screensViewed = 0;
  int _actionsCount = 0;

  String? _appVersion;
  String? _buildNumber;
  String? _deviceModel;
  String? _deviceOsVersion;

  AnalyticsService() {
    _initializeDeviceInfo();
  }

  /// Initialize device and app information
  Future<void> _initializeDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;

      // Get device info (simplified - you can add more details)
      _deviceModel = Platform.isAndroid ? 'Android Device' : 'iOS Device';
      _deviceOsVersion = Platform.operatingSystemVersion;
    } catch (e) {
      print('Error initializing device info: $e');
    }
  }

  /// Start a new analytics session
  Future<void> startSession() async {
    if (_supabase.auth.currentUser == null) return;

    _userId = _supabase.auth.currentUser!.id;
    _sessionStartTime = DateTime.now();
    _screensViewed = 0;
    _actionsCount = 0;

    try {
      final platform = Platform.isAndroid ? 'android' : 'ios';

      final response = await _supabase.from('app_sessions').insert({
        'user_id': _userId,
        'app_platform': platform,
        'app_version': '$_appVersion+$_buildNumber',
        'build_number': _buildNumber,
        'session_start': _sessionStartTime!.toIso8601String(),
        'device_model': _deviceModel,
        'device_os_version': _deviceOsVersion,
        'screens_viewed': 0,
        'actions_count': 0,
      }).select().single();

      _sessionId = response['id'];
      print('📊 Analytics session started: $_sessionId');

      // Update app usage stats
      await _updateAppUsageStats(platform);
    } catch (e) {
      print('Error starting analytics session: $e');
    }
  }

  /// End the current session
  Future<void> endSession() async {
    if (_sessionId == null) return;

    try {
      final sessionEnd = DateTime.now();
      final duration = sessionEnd.difference(_sessionStartTime!).inSeconds;

      await _supabase.from('app_sessions').update({
        'session_end': sessionEnd.toIso8601String(),
        'duration_seconds': duration,
        'screens_viewed': _screensViewed,
        'actions_count': _actionsCount,
      }).eq('id', _sessionId!);

      print('📊 Analytics session ended. Duration: $duration seconds');
    } catch (e) {
      print('Error ending analytics session: $e');
    }
  }

  /// Track a user action
  Future<void> trackAction(
    String actionType,
    String actionCategory,
    String actionTarget, {
    String? actionValue,
    String? screenName,
  }) async {
    if (_sessionId == null || _userId == null) return;

    _actionsCount++;

    try {
      await _supabase.from('app_actions').insert({
        'user_id': _userId,
        'session_id': _sessionId,
        'action_type': actionType,
        'action_category': actionCategory,
        'action_target': actionTarget,
        'action_value': actionValue,
        'screen_name': screenName,
      });

      // Update session actions count
      await _supabase
          .from('app_sessions')
          .update({'actions_count': _actionsCount}).eq('id', _sessionId!);
    } catch (e) {
      print('Error tracking action: $e');
    }
  }

  /// Track screen view
  Future<void> trackScreenView(String screenName) async {
    _screensViewed++;
    await trackAction('screen_view', 'navigation', screenName,
        screenName: screenName);

    // Update session screens count
    if (_sessionId != null) {
      try {
        await _supabase
            .from('app_sessions')
            .update({'screens_viewed': _screensViewed}).eq('id', _sessionId!);
      } catch (e) {
        print('Error updating screens viewed: $e');
      }
    }
  }

  /// Track button tap
  Future<void> trackButtonTap(String buttonName,
      {String category = 'interaction', String? screenName}) async {
    await trackAction('button_tap', category, buttonName,
        screenName: screenName);
  }

  /// Track device action (add, remove, configure, etc.)
  Future<void> trackDeviceAction(String actionType, String deviceId,
      {String? screenName}) async {
    await trackAction('device_action', 'device_management', actionType,
        actionValue: deviceId, screenName: screenName);
  }

  /// Track house view/selection
  Future<void> trackHouseView(String houseId, {String? screenName}) async {
    await trackAction('house_view', 'navigation', houseId,
        screenName: screenName);
  }

  /// Track BLE provisioning flow
  Future<void> trackBLEProvisioning(String step,
      {String? deviceId, String? screenName}) async {
    await trackAction('ble_provisioning', 'device_setup', step,
        actionValue: deviceId, screenName: screenName);
  }

  /// Track login
  Future<void> trackLogin() async {
    await trackAction('login', 'authentication', 'login_success');
  }

  /// Track logout
  Future<void> trackLogout() async {
    await trackAction('logout', 'authentication', 'logout');
    await endSession();
  }

  /// Update app usage stats in database
  Future<void> _updateAppUsageStats(String platform) async {
    if (_userId == null) return;

    try {
      // Check if stats exist
      final existing = await _supabase
          .from('app_usage_stats')
          .select()
          .eq('user_id', _userId!)
          .eq('app_platform', platform)
          .maybeSingle();

      if (existing == null) {
        // Create new stats
        await _supabase.from('app_usage_stats').insert({
          'user_id': _userId,
          'app_platform': platform,
          'current_version': '$_appVersion+$_buildNumber',
          'last_version_update': DateTime.now().toIso8601String(),
          'total_sessions': 1,
          'first_used_at': DateTime.now().toIso8601String(),
          'last_used_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Update existing stats
        await _supabase.from('app_usage_stats').update({
          'current_version': '$_appVersion+$_buildNumber',
          'last_used_at': DateTime.now().toIso8601String(),
          'total_sessions': (existing['total_sessions'] ?? 0) + 1,
        }).eq('user_id', _userId!).eq('app_platform', platform);
      }
    } catch (e) {
      print('Error updating app usage stats: $e');
    }
  }

  /// Update session metrics periodically
  Future<void> updateSessionMetrics() async {
    if (_sessionId == null) return;

    try {
      await _supabase.from('app_sessions').update({
        'screens_viewed': _screensViewed,
        'actions_count': _actionsCount,
      }).eq('id', _sessionId!);
    } catch (e) {
      print('Error updating session metrics: $e');
    }
  }
}

// Global analytics instance
final analyticsService = AnalyticsService();
