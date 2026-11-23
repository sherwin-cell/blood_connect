import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/statuses.dart';
import '../domain/entities/account_verification_stage.dart';
import '../domain/repositories/i_verification_repository.dart';
import 'id_verification_flow.dart';
import 'provider/verification_provider.dart';
import 'screens/face_verification_instructions_screen.dart';

/// Account identity verification, always in this order:
///
/// 1. Valid ID (front + back) uploaded to Cloudinary and saved to
///    id_verifications/{uid}. Skipped when an ID is already on file.
/// 2. Selfie, which the backend compares with the ID's front photo.
///
/// The ID must come first because the backend matches the selfie against it;
/// a selfie without an ID on file would only waste a daily attempt.
abstract final class IdentityVerificationFlow {
  /// True when id_verifications/{uid} has both ID images.
  static Future<bool> hasIdOnFile(
    IVerificationRepository repository,
    String uid,
  ) async {
    try {
      final status = await repository.getIdVerificationStatus(uid);
      return status == IdVerificationStatus.submitted;
    } catch (e) {
      debugPrint('Could not check ID submission: $e');
      return false;
    }
  }

  /// Makes sure an ID is on file, running the ID upload flow if not.
  /// Returns false when the user backed out or the ID could not be saved.
  static Future<bool> ensureIdOnFile(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final repository = context.read<IVerificationRepository>();
    if (await hasIdOnFile(repository, user.uid)) return true;
    if (!context.mounted) return false;

    final result = await IdVerificationFlow.start(context);
    if (result == null) return false;

    // Trust what was saved, not what the screens returned.
    final saved = await hasIdOnFile(repository, user.uid);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your ID could not be saved. Please try again.'),
        ),
      );
    }
    return saved;
  }

  /// Runs the whole flow from the dashboard.
  ///
  /// Do not pop the top route after awaiting this: it can complete while the
  /// selfie camera is still open, because the guide screen replaces itself
  /// with the camera (pushReplacement completes the guide's push future).
  /// Callers that want to close themselves should remove their own route.
  static Future<void> start(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue.')),
      );
      return;
    }

    if (!await ensureIdOnFile(context)) return;
    if (!context.mounted) return;
    await startFaceVerification(context);
  }

  /// Selfie step only, for users whose ID is already on file: opens the
  /// guide (FaceVerificationInstructionsScreen → SelfieScreen) without the ID
  /// screens. SelfieScreen still re-checks for an ID before the camera starts.
  ///
  /// Like [start], this can complete while the camera is still open.
  static Future<void> startFaceVerification(BuildContext context) async {
    final navigator = Navigator.of(context);
    final provider = context.read<VerificationProvider>()..reset();
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const FaceVerificationInstructionsScreen(),
        ),
      ),
    );
  }

  /// "Verify Now" / gate button: ID then selfie, or straight to the selfie
  /// when the ID is already on file.
  static Future<void> startForStage(
    BuildContext context,
    AccountVerificationStage stage,
  ) {
    return stage.needsIdUpload
        ? start(context)
        : startFaceVerification(context);
  }
}
