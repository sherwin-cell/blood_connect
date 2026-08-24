import 'package:flutter/material.dart';
import 'identity_verification_info_screen.dart'; // Make sure this points to your starting info screen path

class VerificationRejectedScreen extends StatelessWidget {
  final Map<String, dynamic>? rejectionDetails;

  const VerificationRejectedScreen({super.key, this.rejectionDetails});

  @override
  Widget build(BuildContext context) {
    final adminNotes =
        rejectionDetails?['adminNotes'] ??
        rejectionDetails?['rejectionReason'] ??
        'No specific notes provided by the administrator.';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Blood-Connect Themed Warning / Alert Illustration ---
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // --- Heading ---
              const Text(
                'Verification Not Approved',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // --- Description ---
              Text(
                "We couldn't approve your identity verification at this time. Please review the reason below and submit your verification again.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // --- Reviewer Feedback Box ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reviewer Feedback / Reason:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      adminNotes,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- What you can do section ---
              const Text(
                'What you can do',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              _buildActionTip('Make sure your ID is fully visible.'),
              _buildActionTip('Take the photo in good lighting.'),
              _buildActionTip(
                'Make sure the text and photo on your ID are clear.',
              ),
              _buildActionTip(
                'Submit a new selfie with your face clearly visible.',
              ),
              const SizedBox(height: 36),

              // --- Action Button (Loops back to Identity Verification Info Screen) ---
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const IdentityVerificationInfoScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFC62828,
                    ), // Blood-Connect Red
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Try Verification Again',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(
              Icons.check_circle_outline,
              color: Color(0xFFC62828),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.black.withOpacity(0.7),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
