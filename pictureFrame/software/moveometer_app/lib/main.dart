import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Configuration
import 'config/supabase_config.dart';

// Services
import 'services/auth_service.dart';
import 'services/analytics_service.dart';

// Pages
import 'pages/login_page.dart';
import 'pages/houses_page.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Check network connectivity first (optional - app works without it)
    try {
      print('🌐 Checking network connectivity...');
      final connectivityResult = await Connectivity().checkConnectivity();
      print('📡 Connectivity status: $connectivityResult');

      if (connectivityResult.contains(ConnectivityResult.none)) {
        print('⚠️ No network connection detected');
      }
    } catch (connectivityError) {
      print('⚠️ Connectivity check failed (permission issue?): $connectivityError');
      // Continue anyway - Supabase will handle network errors
    }

    // Give network a moment to stabilize (important on Android)
    await Future.delayed(const Duration(milliseconds: 500));

    print('🔧 Initializing Supabase...');
    print('🔗 URL: $supabaseUrl');

    // Initialize Supabase with timeout
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        print('⚠️ Supabase initialization timed out after 15 seconds');
        throw Exception('Could not connect to server. Please check your internet connection.');
      },
    );

    print('✅ Supabase initialized successfully');

    // Attempt auto-login using saved credentials (non-blocking)
    try {
      print('🔐 Attempting auto-login...');
      final authService = AuthService(Supabase.instance.client);
      final autoLoginSuccess = await authService.autoLogin().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('⚠️ Auto-login timed out');
          return false;
        },
      );

      if (autoLoginSuccess) {
        print('✅ Auto-login successful');
      } else {
        print('ℹ️ Auto-login skipped (no saved credentials or invalid)');
      }
    } catch (e) {
      // Auto-login failure should not prevent app from starting
      print('⚠️ Auto-login failed: $e');
    }
  } catch (e) {
    // Critical error during initialization
    print('❌ App initialization failed: $e');
    print('📱 App will continue to launch with limited functionality');
    // App will still run but show error in UI
  }

  runApp(const MyApp());
}

// Get Supabase client (use this throughout your app)
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'moveOmeter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667eea), // Purple brand color
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// Auth gate - checks if user is logged in
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    // Add lifecycle observer for app pause/resume
    WidgetsBinding.instance.addObserver(this);

    // Start analytics session if user is already logged in
    if (supabase.auth.currentSession != null) {
      analyticsService.startSession();
    }

    // Listen for auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.signedIn) {
        // User just logged in - start analytics session
        analyticsService.startSession();
      } else if (event == AuthChangeEvent.signedOut) {
        // User logged out - end analytics session
        analyticsService.endSession();
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (supabase.auth.currentSession == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - update session metrics
        analyticsService.updateSessionMetrics();
        break;
      case AppLifecycleState.paused:
        // App went to background - update session metrics
        analyticsService.updateSessionMetrics();
        break;
      case AppLifecycleState.detached:
        // App is closing - end session
        analyticsService.endSession();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;

    // If user is logged in, show home page, otherwise show login
    return session == null ? const LoginPage() : const HomePage();
  }
}
