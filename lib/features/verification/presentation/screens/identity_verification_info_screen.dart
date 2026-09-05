import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'personal_details_screen.dart';

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
              // Header Section
              const Text(
                'Complete your verification',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Complete these simple steps to become a verified user.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              // Process Timeline Header
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

              // Step Timeline List (Compact layout)
              Expanded(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildStepItem(
                      '1',
                      'Personal Details',
                      'Fill out core profile info',
                    ),
                    _buildStepItem(
                      '2',
                      'Submit a valid ID',
                      'Choose your government ID',
                    ),
                    _buildStepItem(
                      '3',
                      'Capture ID (Front & Back)',
                      'Take clear photos of your ID',
                    ),
                    _buildStepItem(
                      '4',
                      'Take a selfie',
                      'Follow camera instructions',
                    ),
                    _buildStepItem(
                      '5',
                      'Face verification',
                      'Match selfie with ID photo',
                    ),
                    _buildStepItem(
                      '6',
                      'Review your submission',
                      'Check details are readable',
                    ),
                    _buildStepItem(
                      '7',
                      'PRC verification',
                      'Admin final approval',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Bottom Action Area
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PersonalDetailsScreen(),
                      ),
                    );
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
                  'Takes about a few minutes to complete',
                  style: TextStyle(fontSize: 10.5, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Compact Widget helper for timeline steps
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
                  color: const Color(0xFFEF9A9A).withOpacity(0.6),
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
                    color: Colors.black.withOpacity(0.55),
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
