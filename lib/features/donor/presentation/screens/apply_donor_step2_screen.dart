import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'apply_donor_step3_screen.dart';

class ApplyDonorStep2Screen extends StatefulWidget {
  final String bloodType;
  final bool isAvailable;

  const ApplyDonorStep2Screen({
    super.key,
    required this.bloodType,
    required this.isAvailable,
  });

  @override
  State<ApplyDonorStep2Screen> createState() => _ApplyDonorStep2ScreenState();
}

class _ApplyDonorStep2ScreenState extends State<ApplyDonorStep2Screen> {
  DateTime? _lastDonationDate;

  Future<void> _pickLastDonationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 90)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _lastDonationDate = picked;
      });
    }
  }

  void _nextStep() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyDonorStep3Screen(
          bloodType: widget.bloodType,
          isAvailable: widget.isAvailable,
          lastDonationDate: _lastDonationDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Step 2: Donation History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last Donation Date (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),

            const SizedBox(height: 8),

            InkWell(
              onTap: _pickLastDonationDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _lastDonationDate == null
                          ? 'Select date if you have donated before'
                          : '${_lastDonationDate!.day}/${_lastDonationDate!.month}/${_lastDonationDate!.year}',
                      style: TextStyle(
                        color: _lastDonationDate == null
                            ? Colors.grey.shade600
                            : Colors.black87,
                      ),
                    ),
                    const Icon(Icons.calendar_today_rounded, size: 20),
                  ],
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Next: Donor Eligibility',
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
    );
  }
}
