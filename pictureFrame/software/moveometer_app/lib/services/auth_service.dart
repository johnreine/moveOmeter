import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';

/// Authentication service with secure credential storage and auto-login
class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  /// Attempt auto-login using saved credentials
  /// Returns true if login successful, false otherwise
  /// Called on app startup to restore session
  Future<bool> autoLogin() async {
    try {
      // Check if credentials exist
      final hasCredentials = await StorageService.hasCredentials();
      if (!hasCredentials) {
        return false;
      }

      // Retrieve saved credentials
      final creds = await StorageService.getCredentials();
      if (creds['email'] == null || creds['password'] == null) {
        return false;
      }

      // Attempt sign in
      final response = await _supabase.auth.signInWithPassword(
        email: creds['email']!,
        password: creds['password']!,
      );

      // Verify user exists and is active
      if (response.user != null) {
        final profile = await _supabase
            .from('user_profiles')
            .select('is_active')
            .eq('id', response.user!.id)
            .maybeSingle();

        if (profile != null && profile['is_active'] == true) {
          return true;
        } else {
          // Account inactive, sign out and clear credentials
          await signOut();
          return false;
        }
      }

      return false;
    } catch (e) {
      // Auto-login failed (invalid credentials, network error, etc.)
      // Clear saved credentials to prevent repeated failures
      await StorageService.clearCredentials();
      return false;
    }
  }

  /// Sign in with email and password
  /// Optionally save credentials for auto-login (default: true)
  /// Throws exception on login failure
  Future<AuthResponse> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    // Attempt sign in
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Login failed');
    }

    // Check if account is active
    final profile = await _supabase
        .from('user_profiles')
        .select('is_active, full_name')
        .eq('id', response.user!.id)
        .single();

    if (profile['is_active'] == false) {
      await _supabase.auth.signOut();
      throw Exception('Your account has been deactivated. Please contact an administrator.');
    }

    // Update last login timestamp
    await _supabase
        .from('user_profiles')
        .update({'last_login': DateTime.now().toIso8601String()})
        .eq('id', response.user!.id);

    // Save credentials if remember me is enabled
    if (rememberMe) {
      await StorageService.saveCredentials(email, password);
    }

    return response;
  }

  /// Sign up new user with email and password
  /// Does NOT automatically save credentials (user must confirm email first)
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    return response;
  }

  /// Sign out current user and clear saved credentials
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await StorageService.clearCredentials();
  }

  /// Get current user session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => currentSession != null;
}
