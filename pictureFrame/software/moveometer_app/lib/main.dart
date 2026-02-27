import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Configuration
import 'config/supabase_config.dart';

// Services
import 'services/auth_service.dart';

// Pages
import 'pages/login_page.dart';
import 'pages/houses_page.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Attempt auto-login using saved credentials
  final authService = AuthService(Supabase.instance.client);
  await authService.autoLogin();

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

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Listen for auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;

    // If user is logged in, show home page, otherwise show login
    return session == null ? const LoginPage() : const HomePage();
  }
}
