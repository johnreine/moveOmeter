import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settingsService = SettingsService();
  final _supabase = Supabase.instance.client;

  bool _use24HourFormat = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  int _defaultTimeRange = 7;
  String _appVersion = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    _use24HourFormat = await _settingsService.getUse24HourFormat();
    _themeMode = await _settingsService.getThemeMode();
    _notificationsEnabled = await _settingsService.getNotificationsEnabled();
    _defaultTimeRange = await _settingsService.getDefaultTimeRange();

    setState(() => _isLoading = false);
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  Future<void> _logout() async {
    final authService = AuthService(_supabase);
    await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Display Preferences
                _buildSectionHeader('Display'),
                _buildTimeFormatTile(),
                _buildThemeModeTile(),
                _buildDefaultTimeRangeTile(),

                const Divider(height: 32),

                // Notifications
                _buildSectionHeader('Notifications'),
                _buildNotificationsTile(),

                const Divider(height: 32),

                // Account
                _buildSectionHeader('Account'),
                _buildAccountEmailTile(),
                _buildChangePasswordTile(),

                const Divider(height: 32),

                // About
                _buildSectionHeader('About'),
                _buildAppVersionTile(),
                _buildPrivacyPolicyTile(),
                _buildTermsOfServiceTile(),

                const Divider(height: 32),

                // Logout
                _buildLogoutTile(),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildTimeFormatTile() {
    return SwitchListTile(
      title: const Text('24-Hour Time'),
      subtitle: Text(_use24HourFormat ? '23:00' : '11:00 PM'),
      value: _use24HourFormat,
      onChanged: (value) async {
        await _settingsService.setUse24HourFormat(value);
        setState(() => _use24HourFormat = value);
      },
    );
  }

  Widget _buildThemeModeTile() {
    return ListTile(
      title: const Text('Theme'),
      subtitle: Text(_getThemeModeLabel(_themeMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(),
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System Default';
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: _themeMode,
              onChanged: (value) async {
                if (value != null) {
                  await _settingsService.setThemeMode(value);
                  setState(() => _themeMode = value);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: _themeMode,
              onChanged: (value) async {
                if (value != null) {
                  await _settingsService.setThemeMode(value);
                  setState(() => _themeMode = value);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: _themeMode,
              onChanged: (value) async {
                if (value != null) {
                  await _settingsService.setThemeMode(value);
                  setState(() => _themeMode = value);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultTimeRangeTile() {
    return ListTile(
      title: const Text('Default Chart Range'),
      subtitle: Text(_getTimeRangeLabel(_defaultTimeRange)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showTimeRangeDialog(),
    );
  }

  String _getTimeRangeLabel(int days) {
    if (days == 1) return '24 Hours';
    if (days == 7) return '7 Days';
    if (days == 30) return '30 Days';
    return '$days Days';
  }

  void _showTimeRangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Chart Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              title: const Text('24 Hours'),
              value: 1,
              groupValue: _defaultTimeRange,
              onChanged: (value) async {
                if (value != null) {
                  await _settingsService.setDefaultTimeRange(value);
                  setState(() => _defaultTimeRange = value);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
            RadioListTile<int>(
              title: const Text('7 Days'),
              value: 7,
              groupValue: _defaultTimeRange,
              onChanged: (value) async {
                if (value != null) {
                  await _settingsService.setDefaultTimeRange(value);
                  setState(() => _defaultTimeRange = value);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
            RadioListTile<int>(
              title: const Text('30 Days'),
              value: 30,
              groupValue: _defaultTimeRange,
              onChanged: (value) async {
                if (value != null) {
                  await _settingsService.setDefaultTimeRange(value);
                  setState(() => _defaultTimeRange = value);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTile() {
    return SwitchListTile(
      title: const Text('Enable Notifications'),
      subtitle: const Text('Receive alerts about activity changes'),
      value: _notificationsEnabled,
      onChanged: (value) async {
        await _settingsService.setNotificationsEnabled(value);
        setState(() => _notificationsEnabled = value);
      },
    );
  }

  Widget _buildAccountEmailTile() {
    final email = _supabase.auth.currentUser?.email ?? 'Not logged in';
    return ListTile(
      leading: const Icon(Icons.email),
      title: const Text('Email'),
      subtitle: Text(email),
    );
  }

  Widget _buildChangePasswordTile() {
    return ListTile(
      leading: const Icon(Icons.lock),
      title: const Text('Change Password'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: Navigate to change password page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Change password feature coming soon')),
        );
      },
    );
  }

  Widget _buildAppVersionTile() {
    return ListTile(
      leading: const Icon(Icons.info),
      title: const Text('App Version'),
      subtitle: Text(_appVersion.isEmpty ? 'Loading...' : _appVersion),
    );
  }

  Widget _buildPrivacyPolicyTile() {
    return ListTile(
      leading: const Icon(Icons.privacy_tip),
      title: const Text('Privacy Policy'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: Open privacy policy
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy policy coming soon')),
        );
      },
    );
  }

  Widget _buildTermsOfServiceTile() {
    return ListTile(
      leading: const Icon(Icons.description),
      title: const Text('Terms of Service'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: Open terms of service
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terms of service coming soon')),
        );
      },
    );
  }

  Widget _buildLogoutTile() {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text(
        'Logout',
        style: TextStyle(color: Colors.red),
      ),
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
        );

        if (confirm == true && mounted) {
          await _logout();
        }
      },
    );
  }
}
