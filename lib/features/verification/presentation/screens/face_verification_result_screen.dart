import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../provider/verification_provider.dart';

class FaceVerificationResultScreen extends StatelessWidget {
  final bool success;
  final VoidCallback? onComplete;

  const FaceVerificationResultScreen({
    super.key,
    required this.success,
    this.onComplete,
  });

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
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(passed ? 'Done' : 'Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
