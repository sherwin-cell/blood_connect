import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/profile_service.dart';
import 'complete_profile_screen.dart';
import '../../dashboard/presentation/home_dashboard.dart';

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User session expired. Please log in again.')),
      );
    }

    return FutureBuilder<bool>(
      future: ProfileService().isProfileCompleted(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return const HomeDashboard();
        }

        return const CompleteProfileScreen();
      },
    );
  }
}
