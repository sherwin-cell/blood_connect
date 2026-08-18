import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../onboarding/presentation/welcome_screen.dart';
import '../../profile/presentation/profile_gate.dart';
import 'email_verification_screen.dart';

/// Single source of truth for unauthenticated → verified → profile routing.
/// Uses [userChanges] so email verification after [User.reload] is observed.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // Unauthenticated → Welcome
        if (user == null) {
          return const WelcomeScreen();
        }

        final isGoogleUser = user.providerData.any(
          (provider) => provider.providerId == 'google.com',
        );

        // Email/password users must verify before continuing
        if (!isGoogleUser && !user.emailVerified) {
          return const EmailVerificationScreen();
        }

        return ProfileGate(user: user);
      },
    );
  }
}
