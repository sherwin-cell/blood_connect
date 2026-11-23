import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../identity_verification_flow.dart';

class IdentityVerificationInfoScreen extends StatelessWidget {
  const IdentityVerificationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Identity Verification',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Identity Verification',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Upload a valid ID first, then take a selfie. We match your '
                'face to your ID photo.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'VERIFICATION PROCESS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildStepItem(
                      '1',
                      'Choose a valid ID',
                      'Select the government-issued ID type you will upload',
                    ),
                    _buildStepItem(
                      '2',
                      'Upload front and back',
                      'Capture both sides clearly. Skipped if your ID is '
                          'already on file',
                    ),
                    _buildStepItem(
                      '3',
                      'Take a selfie',
                      'Follow the live face steps in good light',
                    ),
                    _buildStepItem(
                      '4',
                      'Get verified',
                      'Your selfie is matched to your ID photo. You have 5 '
                          'tries a day',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final thisRoute = ModalRoute.of(context);
                    // ID first, then selfie.
                    await IdentityVerificationFlow.start(context);
                    // Remove only this intro screen, wherever it now sits.
                    // start() can return while the selfie camera is open
                    // (the guide replaces itself with it), so popping the
                    // top route here would close the camera.
                    if (navigator.mounted &&
                        thisRoute != null &&
                        thisRoute.isActive) {
                      navigator.removeRoute(thisRoute);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Takes about a minute to complete',
                  style: TextStyle(fontSize: 10.5, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStepItem(
    String stepNumber,
    String title,
    String subtitle, {
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFC62828),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 1.5,
                  height: 14,
                  color: const Color(0xFFEF9A9A).withValues(alpha: 0.6),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
