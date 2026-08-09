import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart'; // Adjust import path
import '../../../../core/services/firestore_service.dart';
import '../../data/repositories/verification_repository_impl.dart'; // adjust path to match your project
import '../../data/services/ocr_service.dart';
import '../../data/services/face_detector_service.dart';
import '../../data/services/cloudinary_service.dart';
import '../../data/services/arsa_face_service.dart'; // 1. Added ARSA Service Import
import '../provider/verification_provider.dart';
import 'select_valid_id_screen.dart';

class IdentityVerificationInfoScreen extends StatelessWidget {
  const IdentityVerificationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Hide back when this screen is the ProfileGate root (required step).
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Shield Icon Header
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.verified_user_rounded,
                            size: 56,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title & Subtitle
                      const Text(
                        'Verify Your Identity',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'To keep Blood-Connect safe,\nplease verify your identity.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Requirement Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: const [
                            _InfoRow(
                              icon: Icons.badge_outlined,
                              text: 'Government-issued ID',
                            ),
                            SizedBox(height: 16),
                            _InfoRow(
                              icon: Icons.wb_sunny_outlined,
                              text: 'Good Lighting',
                            ),
                            SizedBox(height: 16),
                            _InfoRow(
                              icon: Icons.face_outlined,
                              text: 'A quick selfie',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider(
                          create: (_) => VerificationProvider(
                            // DEV ONLY: API key in the client for local testing.
                            // Production must proxy ARSA via a backend/Cloud Function.
                            arsaFaceService: ArsaFaceService(
                              'eb3e143543cc1eee84640d94770a6e290bfc86bb5f65c5ef4099e76116013e90',
                            ),
                            repository: VerificationRepositoryImpl(
                              ocrService: OcrService(),
                              faceDetectorService: FaceDetectorService(),
                              cloudinaryService: CloudinaryService(),
                              firestoreService: FirestoreService(),
                            ),
                          ),
                          child: const SelectValidIdScreen(),
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primaryRed, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryRed, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
