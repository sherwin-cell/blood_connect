import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/auth/presentation/login_signup_screen.dart'; // Add your LoginScreen import here
import 'features/auth/data/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'features/profile/presentation/profile_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const BloodConnectApp());
}

class BloodConnectApp extends StatefulWidget {
  const BloodConnectApp({super.key});

  @override
  State<BloodConnectApp> createState() => _BloodConnectAppState();
}

class _BloodConnectAppState extends State<BloodConnectApp> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initPasswordlessLinkListener();
  }

  /// Initializes deep-link processing for Firebase Passwordless Auth
  Future<void> _initPasswordlessLinkListener() async {
    _appLinks = AppLinks();

    // 1. Check for initial link if app was cold-started by tapping the magic link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleIncomingLink(initialUri.toString());
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // 2. Listen to stream for links opened while the app is running/paused in background
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleIncomingLink(uri.toString());
      },
      onError: (err) {
        debugPrint('Error listening to deep links: $err');
      },
    );
  }

  /// Processes incoming URL and signs the user in if it's a valid auth link
  Future<void> _handleIncomingLink(String link) async {
    if (_authService.isSignInWithEmailLink(link)) {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('emailForSignIn');
      final pendingName = prefs.getString('pendingUserName');

      if (email != null && email.isNotEmpty) {
        try {
          final credential = await _authService.signInWithEmailLink(
            email: email,
            emailLink: link,
          );

          final user = credential.user;
          if (user != null) {
            final nameToUse = pendingName ?? user.displayName ?? 'New User';

            if (user.displayName == null || user.displayName != nameToUse) {
              await user.updateDisplayName(nameToUse);
            }

            await _firestoreService.createUserProfile(
              uid: user.uid,
              fullname: nameToUse,
              email: user.email ?? email,
            );
          }

          // Clean up SharedPreferences after successful auth
          await prefs.remove('emailForSignIn');
          await prefs.remove('pendingUserName');

          debugPrint('Successfully authenticated with magic link!');

          // NOTE: Navigator call removed here!
          // FirebaseAuth userChanges() stream will trigger AuthGate rebuild automatically.
        } catch (e) {
          debugPrint('Error signing in with link: $e');
        }
      } else {
        debugPrint('No saved email found in SharedPreferences for sign-in.');
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blood-Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      home: const AuthGate(),
    );
  }
}

/// Single source of truth for top-level app routing
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        // 1. Firebase is initializing or authenticating
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // 2. User is signed in -> render ProfileGate
        if (snapshot.hasData && snapshot.data != null) {
          return const ProfileGate();
        }

        // 3. User is signed out -> render Login
        return const LoginScreen();
      },
    );
  }
}
