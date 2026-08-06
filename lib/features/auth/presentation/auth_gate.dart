import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../onboarding/presentation/welcome_screen.dart';
import '../../profile/presentation/profile_gate.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Unauthenticated -> Welcome / Login
        if (!snapshot.hasData || snapshot.data == null) {
          return const WelcomeScreen();
        }

        // Authenticated -> ProfileGate (complete profile + verification)
        return ProfileGate(user: snapshot.data!);
      },
    );
  }
}
