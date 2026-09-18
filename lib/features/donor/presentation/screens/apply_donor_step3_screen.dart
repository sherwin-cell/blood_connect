import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'apply_donor_step4_screen.dart';

class ApplyDonorStep3Screen extends StatefulWidget {
  final String bloodType;
  final bool isAvailable;
  final DateTime? lastDonationDate;

  const ApplyDonorStep3Screen({
    super.key,
    required this.bloodType,
    required this.isAvailable,
    this.lastDonationDate,
  });

  @override
  State<ApplyDonorStep3Screen> createState() => _ApplyDonorStep3ScreenState();
}

class _ApplyDonorStep3ScreenState extends State<ApplyDonorStep3Screen> {
  final _formKey = GlobalKey<FormState>();

  bool? _feelsHealthy;
  bool? _hasRecentIllness;
  bool? _hasRecentMedication;
  bool? _hasRecentTattooOrPiercing;
  bool? _hasDonatedRecently;

  bool _isLoading = false;

  bool get _screeningPassed {
    return _feelsHealthy == true &&
        _hasRecentIllness == false &&
        _hasRecentMedication == false &&
        _hasRecentTattooOrPiercing == false &&
        _hasDonatedRecently == false;
  }

  Map<String, dynamic> get _eligibilityAnswers {
    return {
      'feelsHealthy': _feelsHealthy,
      'hasRecentIllness': _hasRecentIllness,
      'hasRecentMedication': _hasRecentMedication,
      'hasRecentTattooOrPiercing': _hasRecentTattooOrPiercing,
      'hasDonatedRecently': _hasDonatedRecently,
    };
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_feelsHealthy == null ||
        _hasRecentIllness == null ||
        _hasRecentMedication == null ||
        _hasRecentTattooOrPiercing == null ||
        _hasDonatedRecently == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all eligibility questions.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyDonorStep4Screen(
          bloodType: widget.bloodType,
          isAvailable: widget.isAvailable,
          lastDonationDate: widget.lastDonationDate,
          isEligible: _screeningPassed,
          eligibilityAnswers: _eligibilityAnswers,
        ),
      ),
    );
  }

  Widget _yesNoQuestion({
    required String question,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yes'),
                  value: true,
                  groupValue: value,
                  onChanged: onChanged,
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('No'),
                  value: false,
                  groupValue: value,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Step 3: Donor Eligibility',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Please answer these questions honestly. This is a preliminary self-screening only. Final donor eligibility will be determined by qualified PRC or medical personnel.',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'DONOR SCREENING',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 12),

              _yesNoQuestion(
                question:
                    'Do you currently feel healthy and well enough to donate blood?',
                value: _feelsHealthy,
                onChanged: (value) {
                  setState(() => _feelsHealthy = value);
                },
              ),

              _yesNoQuestion(
                question:
                    'Have you recently been sick, had a fever, or had an infection?',
                value: _hasRecentIllness,
                onChanged: (value) {
                  setState(() => _hasRecentIllness = value);
                },
              ),

              _yesNoQuestion(
                question:
                    'Are you currently taking medication or have you recently taken medication that may affect blood donation?',
                value: _hasRecentMedication,
                onChanged: (value) {
                  setState(() => _hasRecentMedication = value);
                },
              ),

              _yesNoQuestion(
                question:
                    'Have you recently had a tattoo, piercing, or similar procedure?',
                value: _hasRecentTattooOrPiercing,
                onChanged: (value) {
                  setState(() => _hasRecentTattooOrPiercing = value);
                },
              ),

              _yesNoQuestion(
                question:
                    'Have you donated blood recently and may still be within a required donation interval?',
                value: _hasDonatedRecently,
                onChanged: (value) {
                  setState(() => _hasDonatedRecently = value);
                },
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Text(
                  'Answering these questions does not guarantee that you can donate. PRC or medical personnel will conduct the actual donor screening before blood collection.',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next: Review Application',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
}
