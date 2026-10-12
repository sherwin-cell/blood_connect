import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../id_verification_flow.dart';
import '../provider/verification_provider.dart';

class FaceVerificationResultScreen extends StatelessWidget {
  final bool success;

  const FaceVerificationResultScreen({super.key, required this.success});

  Future<void> _continueToId(BuildContext context) async {
    final provider = context.read<VerificationProvider>();

    final passed = success && provider.isFaceVerified;

    if (!passed) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('FACE RESULT: Continue to ID pressed');
    debugPrint('FACE RESULT: Starting ID verification flow');
    debugPrint('====================================================');

    final result = await IdVerificationFlow.start(context);

    if (!context.mounted) {
      return;
    }

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('FACE RESULT: ID verification flow returned');
    debugPrint('FACE RESULT: result == null = ${result == null}');
    debugPrint('====================================================');

    if (result == null) {
      debugPrint(
        'FACE RESULT: ID verification was cancelled or returned without result.',
      );

      return;
    }

    debugPrint('FACE RESULT: ID submission result received.');
    debugPrint('FACE RESULT: ID type = ${result.idType}');
    debugPrint('FACE RESULT: validation status = ${result.validationStatus}');
    debugPrint('FACE RESULT: ID submission completed.');

    // ----------------------------------------------------------
    // IMPORTANT
    // ----------------------------------------------------------
    // The ID flow has returned successfully.
    //
    // We do NOT:
    // - push SelectValidIdScreen again
    // - push FaceVerificationResultScreen again
    // - return to SelfieScreen
    //
    // We want the verification process to finish here and return
    // to the existing HomeTabView.
    // ----------------------------------------------------------

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('FACE RESULT: Closing verification screens');
    debugPrint('FACE RESULT: Returning to HomeTabView');
    debugPrint('====================================================');

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerificationProvider>();

    final passed = success && provider.isFaceVerified;

    final message = passed
        ? 'Your face has been verified automatically. No admin approval is required.'
        : (provider.errorMessage ??
              'Face verification did not pass. Please try again.');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              Icon(
                passed ? Icons.check_circle_rounded : Icons.error_outline,
                size: 88,
                color: passed ? Colors.green : AppColors.primaryRed,
              ),

              const SizedBox(height: 20),

              Text(
                passed ? 'Face Verified' : 'Face Verification Failed',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                message,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: passed
                      ? () => _continueToId(context)
                      : () {
                          Navigator.of(context).pop();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(passed ? 'Continue to ID' : 'Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
