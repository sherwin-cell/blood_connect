import 'package:flutter/material.dart';

class VerificationPendingScreen extends StatelessWidget {
  const VerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Collect specific theme colors (e.g., Blood-Connect red)
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Submission Received'),
        // Since we got here via pushAndRemoveUntil, there is no back button.
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),

            // 1. Hero Icon (Animated or Static Checkmark)
            // Using a stacked design for a modern confirmation look
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 80,
                    color: primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // 2. Main Title (Clear Status)
            Text(
              'Identity Documents Submitted',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.headlineLarge?.color ?? Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // 3. Explanation Text (Managing Expectations)
            // Use standard terms like "Human-in-the-Loop Approval"
            // from your capstone terminology.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Thank you for submitting your ID and selfie. Our AI services successfully processed and uploaded your data.\n\n'
                'Your application is now under manual review by the PRC Administrator. This typically takes 1–3 business days.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5, // Improves readability
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Optional Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    size: 16,
                    color: Colors.amber[900],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'STATUS: PENDING ADMIN REVIEW',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[900],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // 4. Final Action Button (Return to Dashboard)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Return to Dashboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
