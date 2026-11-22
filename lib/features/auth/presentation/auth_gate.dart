import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/push_notification_service.dart';
import '../../onboarding/presentation/welcome_screen.dart';
import '../../profile/presentation/profile_gate.dart';
import '../../splash/presentation/splash_screen.dart';
import 'email_verification_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final user = snapshot.data;

        debugPrint('========== AUTH DEBUG ==========');
        debugPrint('Current User: ${user?.uid}');
        debugPrint('Email: ${user?.email}');
        debugPrint('Display Name: ${user?.displayName}');
        debugPrint('================================');

        if (user == null) {
          unawaited(PushNotificationService.instance.clearRegisteredUser());
          return const WelcomeScreen();
        }

        final isGoogleUser = user.providerData.any(
          (provider) => provider.providerId == 'google.com',
        );

        if (!isGoogleUser && !user.emailVerified) {
          unawaited(PushNotificationService.instance.clearRegisteredUser());
          return const EmailVerificationScreen();
        }

        unawaited(_registerNotifications(user.uid));

        return ProfileGate(user: user);
      },
    );
  }

  Future<void> _registerNotifications(String uid) async {
    try {
      await PushNotificationService.instance.registerTokenForUser(uid);
    } catch (error, stackTrace) {
      debugPrint('Notification token registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
