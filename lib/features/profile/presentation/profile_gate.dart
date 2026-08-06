import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/user_profile_model.dart';
import 'complete_profile_screen.dart';
import '../../dashboard/presentation/home_dashboard.dart';
import '../../verification/presentation/screens/identity_verification_info_screen.dart';
import '../../verification/presentation/screens/verification_pending_screen.dart';

class ProfileGate extends StatelessWidget {
  final User user;

  const ProfileGate({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: FirestoreService().getUserProfileStream(user.uid),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            ),
          );
        }

        if (profileSnapshot.hasError) {
          debugPrint(
            'Firestore Profile Stream Error: ${profileSnapshot.error}',
          );
        }

        final profile = profileSnapshot.data;

        // Prefer explicit flag written by ProfileService; fall back to required fields
        // so older docs without the flag still route correctly.
        final isProfileComplete =
            profile != null &&
            (profile.profileCompleted ||
                (profile.fullName.trim().isNotEmpty &&
                    profile.bloodType.trim().isNotEmpty &&
                    profile.phoneNumber.trim().isNotEmpty));

        if (!isProfileComplete) {
          return const CompleteProfileScreen(
            key: ValueKey('CompleteProfileScreen_Fresh'),
          );
        }

        final status = (profile.verificationStatus).toLowerCase().trim();

        switch (status) {
          case 'approved':
            return const HomeDashboard();

          case 'pending':
            return const VerificationPendingScreen();

          case 'rejected':
          case 'unverified':
          default:
            return const IdentityVerificationInfoScreen();
        }
      },
    );
  }
}
