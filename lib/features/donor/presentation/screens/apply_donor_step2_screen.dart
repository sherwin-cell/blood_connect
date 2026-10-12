import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../donor/presentation/widgets/step_indicator.dart';
import 'apply_donor_step3_screen.dart';

class ApplyDonorStep2Screen extends StatefulWidget {
  final Map<String, dynamic> personalData;

  const ApplyDonorStep2Screen({super.key, required this.personalData});

  @override
  State<ApplyDonorStep2Screen> createState() => _ApplyDonorStep2ScreenState();
}

class _ApplyDonorStep2ScreenState extends State<ApplyDonorStep2Screen> {
  static const Color donorGreen = Color(0xFF2E7D32);

  final _formKey = GlobalKey<FormState>();

  bool _knowsBloodType = true;
  String _selectedBloodType = 'O+';
  String _donorCategory = 'First-Time Donor';
  final _notesController = TextEditingController();

  final List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;

    final donationHistoryData = {
      ...widget.personalData,
      'bloodType': _knowsBloodType ? _selectedBloodType : 'Unknown',
      'donorCategory': _donorCategory,
      'additionalNotes': _notesController.text.trim(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyDonorStep3Screen(
          personalData: donationHistoryData,
          bloodType: _knowsBloodType ? _selectedBloodType : 'Unknown',
          isAvailable: true,
          lastDonationDate: null,
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

  @override
  Widget build(BuildContext context) {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Indicator
              const DonorStepIndicator(currentStep: 2),

              const SizedBox(height: 16),

              // Header Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: donorGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: donorGreen.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bloodtype_outlined,
                      color: donorGreen,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Donor Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: donorGreen,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'This information will help us match you with blood donation opportunities.',
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

              // Blood Type Section
              _buildSectionTitle('Blood Type'),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<bool>(
                      value: true,
                      groupValue: _knowsBloodType,
                      activeColor: donorGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I know my blood type',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _knowsBloodType = val!;
                        });
                      },
                    ),
                    if (_knowsBloodType) ...[
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedBloodType,
                        decoration: InputDecoration(
                          labelText: 'Blood Type',
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          prefixIcon: const Icon(
                            Icons.bloodtype_outlined,
                            color: donorGreen,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: donorGreen,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: _bloodTypes
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(
                                  type,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedBloodType = val ?? 'O+';
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    RadioListTile<bool>(
                      value: false,
                      groupValue: _knowsBloodType,
                      activeColor: donorGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "I don't know my blood type yet.",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _knowsBloodType = val!;
                        });
                      },
                    ),
                    if (!_knowsBloodType) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: donorGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You can still register as a donor. Your blood type will be determined during actual donation at PRC.',
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Donor Category Section
              _buildSectionTitle('Donor Category'),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'First-Time Donor',
                      groupValue: _donorCategory,
                      activeColor: donorGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'First-Time Donor',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onChanged: (val) => setState(() => _donorCategory = val!),
                    ),
                    RadioListTile<String>(
                      value: 'Regular Donor',
                      groupValue: _donorCategory,
                      activeColor: donorGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Regular Donor',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onChanged: (val) => setState(() => _donorCategory = val!),
                    ),
                    RadioListTile<String>(
                      value: 'Lapse Donor',
                      groupValue: _donorCategory,
                      activeColor: donorGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Lapse Donor',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      secondary: IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: donorGreen,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Lapse Donor'),
                              content: const Text(
                                'A lapse donor is someone who has donated blood before, but more than 365 days ago.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Close',
                                    style: TextStyle(color: donorGreen),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      onChanged: (val) => setState(() => _donorCategory = val!),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Additional Notes Section
              _buildSectionTitle('Additional Notes (Optional)'),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 200,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. I am willing to donate anytime.',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: donorGreen,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Next Button
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
                        'Next',
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
      ),
    );
  }
}
