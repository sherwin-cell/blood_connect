import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../donor/presentation/widgets/step_indicator.dart';
import 'apply_donor_step4_screen.dart';

class ApplyDonorStep3Screen extends StatefulWidget {
  final Map<String, dynamic> personalData;
  final String bloodType;
  final bool isAvailable;
  final DateTime? lastDonationDate;

  const ApplyDonorStep3Screen({
    super.key,
    required this.personalData,
    required this.bloodType,
    required this.isAvailable,
    this.lastDonationDate,
  });

  @override
  State<ApplyDonorStep3Screen> createState() => _ApplyDonorStep3ScreenState();
}

class _ApplyDonorStep3ScreenState extends State<ApplyDonorStep3Screen> {
  static const Color donorGreen = Color(0xFF2E7D32);

  final _formKey = GlobalKey<FormState>();

  final Map<int, bool?> _answers = {};

  final List<MapEntry<int, String>> _questions = const [
    MapEntry(1, '1. Do you feel well and healthy today?'),
    MapEntry(
      2,
      '2. Have you ever been refused as a blood donor or told not to donate for any reasons?',
    ),
    MapEntry(
      3,
      '3. Have you within the last 12 hours taken liquor, beer, or any drinks with alcohol?',
    ),
    MapEntry(
      4,
      '4. In the past 4 weeks, have you taken any medications and/or vaccinations?',
    ),
    MapEntry(
      5,
      '5. In the past 3 months, have you donated whole blood, platelets, or plasma?',
    ),
    MapEntry(
      6,
      '6. In the past 12 months, had surgical operation, dental extraction, tattoo, or piercing?',
    ),
    MapEntry(
      7,
      '7. Had sexual contact with high risk individuals or engaged in unprotected/casual sex?',
    ),
    MapEntry(
      8,
      '8. Had jaundice, hepatitis, or personal contact with a person who had hepatitis?',
    ),
    MapEntry(
      9,
      '9. Taken prohibited drugs (orally, by nose, or by injection)?',
    ),
    MapEntry(
      10,
      '10. Had a positive test for the HIV virus, Hepatitis virus, Syphilis, or Malaria?',
    ),
    MapEntry(
      11,
      '11. [For Females] Are you currently pregnant, or have you ever been pregnant?',
    ),
  ];

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;

    // Questions 1 to 10 are mandatory; Question 11 is optional
    for (final entry in _questions) {
      if (entry.key != 11 && _answers[entry.key] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please answer mandatory screening questions (1-10).',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyDonorStep4Screen(
          personalData: widget.personalData,
          bloodType: widget.bloodType,
          isAvailable: widget.isAvailable,
          lastDonationDate: widget.lastDonationDate,
          eligibilityAnswers: _answers,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, String questionText) {
    final answer = _answers[index];
    final isOptional = index == 11;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: answer == null
              ? Colors.grey.shade200
              : donorGreen.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: donorGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: donorGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      questionText.substring(questionText.indexOf('.') + 2),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                    if (isOptional)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          '(Optional / For Female Donors)',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAnswerButton(
                  index: index,
                  value: true,
                  label: 'Yes',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAnswerButton(
                  index: index,
                  value: false,
                  label: 'No',
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton({
    required int index,
    required bool value,
    required String label,
    required IconData icon,
  }) {
    final selected = _answers[index] == value;

    return InkWell(
      onTap: () {
        setState(() {
          // Tap again to toggle/undo selection
          if (_answers[index] == value) {
            _answers.remove(index);
          } else {
            _answers[index] = value;
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? donorGreen.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? donorGreen : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? donorGreen : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? donorGreen : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answeredCount = _answers.values
        .where((answer) => answer != null)
        .length;
    final totalQuestions = _questions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Apply as Blood Donor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: donorGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const DonorStepIndicator(currentStep: 3),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: donorGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: donorGreen.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.health_and_safety_outlined,
                    color: donorGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Donor Health Screening',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: donorGreen,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Answer each question honestly. Tap an option again to undo your choice.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: donorGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.checklist_rounded,
                      color: donorGreen,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Screening Progress',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$answeredCount of $totalQuestions answered',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$answeredCount/$totalQuestions',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: donorGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Critical Donor Screening Questions'),
            const SizedBox(height: 8),
            ..._questions.map(
              (question) => _buildQuestionCard(question.key, question.value),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Questions 1 to 10 are required. Question 11 is optional for female donors.',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: donorGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next: Review Application',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Colors.black87,
      ),
    );
  }
}
