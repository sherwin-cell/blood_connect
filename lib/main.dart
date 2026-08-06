import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/data/auth_service.dart';
import 'core/services/firestore_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPasswordlessLinkListener();
    });
  }

  Future<void> _initPasswordlessLinkListener() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleIncomingLink(initialUri.toString());
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleIncomingLink(uri.toString());
      },
      onError: (err) {
        debugPrint('Error listening to deep links: $err');
      },
    );
  }

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

          await prefs.remove('emailForSignIn');
          await prefs.remove('pendingUserName');

          debugPrint('Successfully authenticated with magic link!');
        } catch (e) {
          debugPrint('Error signing in with link: $e');
        }
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
