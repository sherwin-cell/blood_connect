import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class DonorPendingScreen extends StatelessWidget {
  const DonorPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color donorGreen = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Donor Application Status',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: donorGreen,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Status Icon with Soft Pulse/Glow Effect
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: donorGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: donorGreen.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 48,
                    color: donorGreen,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Status Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pending PRC Review',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Application Under Review',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              const Text(
                'Your blood donor application, health screening responses, and identity verification have been successfully submitted to the Philippine Red Cross – Sorsogon Chapter.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Informational Guidance Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: donorGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'What happens next?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildBulletPoint(
                      'Administrators will review your submitted ID and health screening details.',
                    ),
                    const SizedBox(height: 6),
                    _buildBulletPoint(
                      'You will be notified once your donor profile is verified and activated.',
                    ),
                    const SizedBox(height: 6),
                    _buildBulletPoint(
                      'Emergency donation matching requests will become available upon approval.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Back to Home Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/auth-gate', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: donorGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Optional Support text
              TextButton(
                onPressed: () {
                  // Optional: Add help or contact support dialog/action
                },
                child: Text(
                  'Need assistance? Contact PRC Chapter',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 6, color: Color(0xFF2E7D32)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
