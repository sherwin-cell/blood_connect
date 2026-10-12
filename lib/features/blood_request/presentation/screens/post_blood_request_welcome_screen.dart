import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../screens/PostRequestStep1Screen.dart';

class PostBloodRequestWelcomeScreen extends StatelessWidget {
  const PostBloodRequestWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Emergency Blood Request',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primaryRed,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Section: Icon, Title & Subtitle
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryRed.withOpacity(0.15),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      size: 48,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Request Blood in an Emergency',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connect with verified donors near your hospital location quickly through our secure review and matching workflow.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),

              // Middle Section: Quick Steps Overview Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What to expect (4 Quick Steps):',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      stepNumber: '1',
                      title: 'Patient Information',
                      subtitle: 'Name, age, birthday, and contact details',
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: SizedBox(
                        height: 10,
                        child: VerticalDivider(
                          color: Colors.grey,
                          thickness: 1,
                        ),
                      ),
                    ),
                    _buildStepRow(
                      stepNumber: '2',
                      title: 'Blood Type & Quantity',
                      subtitle: 'Required blood type, units, and component',
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: SizedBox(
                        height: 10,
                        child: VerticalDivider(
                          color: Colors.grey,
                          thickness: 1,
                        ),
                      ),
                    ),
                    _buildStepRow(
                      stepNumber: '3',
                      title: 'Hospital & Contact Info',
                      subtitle: 'Admission hospital, physicians, and BRF PDF',
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: SizedBox(
                        height: 10,
                        child: VerticalDivider(
                          color: Colors.grey,
                          thickness: 1,
                        ),
                      ),
                    ),
                    _buildStepRow(
                      stepNumber: '4',
                      title: 'Review & Submit',
                      subtitle: 'Verify details and submit for admin review',
                    ),
                  ],
                ),
              ),

              // Bottom Section: Primary CTA Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PostRequestStep1Screen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for compact step-by-step layout
  static Widget _buildStepRow({
    required String stepNumber,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
