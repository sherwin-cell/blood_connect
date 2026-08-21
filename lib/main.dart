import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/email_verification_screen.dart';
import 'features/onboarding/presentation/welcome_screen.dart';
import 'features/splash/presentation/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BloodConnectApp());
}

class BloodConnectApp extends StatelessWidget {
  const BloodConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blood-Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      // Cold-start splash, then AuthGate owns session routing.
      home: const _AppStartupSplash(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/auth-gate': (context) => const AuthGate(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/verify-email': (context) => const EmailVerificationScreen(),
      },
    );
  }
}

/// Brief branded splash on cold start, then [AuthGate].
/// Login/Register pop to the first route after this replacement, so AuthGate
/// remains the authenticated root (no stack under Dashboard).
class _AppStartupSplash extends StatefulWidget {
  const _AppStartupSplash();

  @override
  State<_AppStartupSplash> createState() => _AppStartupSplashState();
}

class _AppStartupSplashState extends State<_AppStartupSplash> {
  @override
  void initState() {
    super.initState();
    _navigateToAuthGate();
  }

  Future<void> _navigateToAuthGate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
