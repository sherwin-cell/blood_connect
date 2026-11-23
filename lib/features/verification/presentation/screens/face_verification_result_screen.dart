import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../provider/verification_provider.dart';

/// Shows the backend's verdict on the selfie.
///
/// Pops with `true` when the user wants to retake the selfie, otherwise with
/// `false` (back to the dashboard). A failed or rate-limited user still gets
/// into the app, unverified: blood requests and donor features stay locked
/// until they verify or PRC approves them.
class FaceVerificationResultScreen extends StatelessWidget {
  const FaceVerificationResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerificationProvider>();
    final outcome = provider.outcome;
    final status = provider.status;

    final verified = status == FaceVerificationStatus.verified;
    final limitReached = status == FaceVerificationStatus.limitReached;
    final canRetry = !verified && !limitReached && (outcome?.canRetry ?? true);
    final remaining = outcome?.attemptsRemaining;

    final IconData icon;
    final Color color;
    final String title;
    final List<String> lines;

    if (verified) {
      icon = Icons.check_circle_rounded;
      color = Colors.green;
      title = outcome?.alreadyVerified == true
          ? 'Already Verified'
          : 'Identity Verified';
      lines = [
        'Your selfie matches your ID. You can now request blood and apply '
            'as a donor.',
      ];
    } else if (limitReached) {
      icon = Icons.hourglass_bottom_rounded;
      color = Colors.orange;
      title = 'Daily Limit Reached';
      lines = [
        provider.errorMessage ??
            'You have used all face verification attempts for today.',
        'You can keep using Blood-Connect. Blood requests and donor features '
            'unlock once you are verified: try again tomorrow, or wait for PRC '
            'to review your account.',
      ];
    } else {
      icon = Icons.error_outline;
      color = AppColors.primaryRed;
      title = 'Not Verified Yet';
      lines = [
        provider.errorMessage ??
            'Face verification did not pass. Please try again.',
        if (outcome?.savedForReview == true)
          'Your selfie was sent to PRC so they can review your account.',
        if (remaining != null)
          remaining == 1
              ? 'You have 1 attempt left today.'
              : 'You have $remaining attempts left today.',
        if (outcome?.isServerProblem == true)
          'This is a problem on our side, not with your photo, and it did '
              'not use up an attempt. Please try again later.'
        else if (!canRetry)
          'You can keep using Blood-Connect while PRC reviews your account.'
        else
          'Tip: face the camera in good light, without glasses or a mask.',
      ];
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Icon(icon, size: 88, color: color),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                for (final line in lines) ...[
                  Text(
                    line,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
                const Spacer(),
                if (canRetry) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retake Selfie'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: canRetry
                      ? OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Go to Dashboard'),
                        )
                      : ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: verified
                                ? Colors.green
                                : AppColors.primaryRed,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Go to Dashboard'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
