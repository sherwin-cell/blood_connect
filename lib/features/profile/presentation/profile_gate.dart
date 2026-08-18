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
        // 1. Loading State
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryRed),
                ],
              ),
            ),
          );
        }

        if (profileSnapshot.hasError) {
          debugPrint(
            'Firestore Profile Stream Error: ${profileSnapshot.error}',
          );
        }

        final profile = profileSnapshot.data;

        // 2. Profile Data Completeness Check
        // Profile is considered complete if profileCompleted flag is true OR phone number is provided
        final isProfileComplete =
            profile != null &&
            (profile.profileCompleted || profile.phoneNumber.trim().isNotEmpty);

        if (!isProfileComplete) {
          return const CompleteProfileScreen(
            key: ValueKey('CompleteProfileScreen_Fresh'),
          );
        }

        // 3. Identity Verification Routing
        final status = profile.verificationStatus.toLowerCase().trim();

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
