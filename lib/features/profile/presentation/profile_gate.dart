import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/firestore_service.dart';
import '../domain/user_profile_model.dart';
import 'complete_profile_screen.dart';
import '../../dashboard/presentation/home_dashboard.dart';
import '../../splash/presentation/splash_screen.dart';

/// Routes authenticated users by Firestore profile completeness only.
/// ID / face / PRC verification is intentionally not part of this gate.
class ProfileGate extends StatelessWidget {
  final User user;
  final FirestoreService _firestoreService;

  ProfileGate({
    super.key,
    required this.user,
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? FirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _firestoreService.getUserProfileStream(user.uid),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (profileSnapshot.hasError) {
          debugPrint(
            'Firestore Profile Stream Error: ${profileSnapshot.error}',
          );
        }

        final profile = profileSnapshot.data;

        // Missing or incomplete profile → Complete Profile
        final isProfileComplete =
            profile != null &&
            (profile.profileCompleted || profile.phoneNumber.trim().isNotEmpty);

        if (!isProfileComplete) {
          return const CompleteProfileScreen(
            key: ValueKey('CompleteProfileScreen_Fresh'),
          );
        }

        // Complete profile → Dashboard (no identity verification step)
        return const HomeDashboard();
      },
    );
  }
}
