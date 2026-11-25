import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/domain/user_profile_model.dart';
import '../domain/entities/account_verification_stage.dart';
import '../domain/repositories/i_verification_repository.dart';
import 'id_verification_flow.dart';
import 'identity_verification_flow.dart';

/// Identity check before Apply as Blood Requester / Blood Donor.
///
/// Used by every entry point (Home, "Submit a New Request" after a
/// rejection, "Resubmit application") so users learn about missing
/// verification before filling in a form, not when Firestore refuses the
/// final submit. firestore.rules (hasVerifiedIdentity) enforces the same
/// conditions: users/{uid}.faceVerified and an ID on file with both photos.
class VerificationGate {
  VerificationGate._();

  /// Opens [destination] if the user is verified; otherwise explains what is
  /// missing and offers to start that step. [profile] is the live profile
  /// when the caller has one; otherwise it is read from Firestore.
  static Future<void> open(
    BuildContext context, {
    required String userId,
    required Widget destination,
    required String actionName,
    UserProfile? profile,
  }) async {
    final repository = context.read<IVerificationRepository>();
    // Read only when needed, so callers with a live profile (Home) and
    // tests do not need FirestoreService.
    final firestore = profile == null ? context.read<FirestoreService>() : null;

    _showLoading(context);
    UserProfile? current = profile;
    bool hasIdOnFile = false;
    try {
      current ??= await firestore!.getUserProfile(userId);
      hasIdOnFile = await IdentityVerificationFlow.hasIdOnFile(
        repository,
        userId,
      );
    } catch (e) {
      debugPrint('Verification check failed: $e');
    }
    if (!context.mounted) return;
    Navigator.of(context).pop(); // loading

    // 1. Face verification (ID first when there is none on file).
    if (current?.faceVerified != true) {
      final stage = AccountVerificationStage.of(
        faceVerified: false,
        hasSubmittedId: hasIdOnFile,
      );
      _showGateDialog(
        context,
        title: stage.label,
        message: stage.gateMessage(
          actionName,
          lastCheckFailed: current?.faceVerificationFailed ?? false,
        ),
        buttonText: stage.actionLabel,
        onPressed: () => IdentityVerificationFlow.startForStage(context, stage),
      );
      return;
    }

    // 2. ID on file (both photos).
    if (!hasIdOnFile) {
      _showGateDialog(
        context,
        title: 'ID Submission Required',
        message:
            'You must submit a valid government ID before you can '
            '$actionName.',
        buttonText: 'Submit Valid ID',
        // Does not continue to the destination: the user starts again once
        // the ID is saved.
        onPressed: () async {
          await IdVerificationFlow.start(context);
        },
      );
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => destination));
  }

  static void _showLoading(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  static void _showGateDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String buttonText,
    required Future<void> Function() onPressed,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Start the step once the dialog is gone.
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!context.mounted) return;
                try {
                  await onPressed();
                } catch (e) {
                  debugPrint('Verification step failed: $e');
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
