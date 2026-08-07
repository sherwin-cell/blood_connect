import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/verification_provider.dart';

class ReviewAllScreen extends StatefulWidget {
  const ReviewAllScreen({super.key});

  @override
  State<ReviewAllScreen> createState() => _ReviewAllScreenState();
}

class _ReviewAllScreenState extends State<ReviewAllScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _dobController;
  late final TextEditingController _genderController;
  late final TextEditingController _idNumberController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<VerificationProvider>(context, listen: false);
    _nameController = TextEditingController(text: provider.data.extractedName);
    _dobController = TextEditingController(
      text: provider.data.extractedBirthDate,
    );
    _genderController = TextEditingController(
      text: provider.data.extractedGender,
    );
    _idNumberController = TextEditingController(text: provider.data.idNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _submitFinalVerification() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final provider = Provider.of<VerificationProvider>(
        context,
        listen: false,
      );

      // 1. Update verification provider with final user-reviewed OCR data
      provider.updateExtractedData(
        correctedName: _nameController.text.trim().toUpperCase(),
        correctedBirthDate: _dobController.text.trim(),
        correctedGender: _genderController.text.trim(),
        correctedIdNumber: _idNumberController.text.trim(),
      );

      // 2. Submit payload (writes verified details to `users` & `verifications`)
      final success = await provider.submitAllDetails();

      if (!mounted) return;

      if (success) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Submission failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final verificationData = context.watch<VerificationProvider>().data;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Verification Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Card(
                color: Color(0xFFE3F2FD),
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Double-check the text extracted from your ID. Correct any OCR mistakes before submitting.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- 1. CAPTURED IMAGES SECTION ---
              const Text(
                'Captured Documents & Selfie',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (verificationData.idImagePath != null)
                      _buildImagePreview(
                        label: 'Front ID',
                        path: verificationData.idImagePath!,
                      ),
                    if (verificationData.backIdImagePath != null)
                      _buildImagePreview(
                        label: 'Back ID',
                        path: verificationData.backIdImagePath!,
                      ),
                    if (verificationData.selfiePath != null)
                      _buildImagePreview(
                        label: 'Selfie',
                        path: verificationData.selfiePath!,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- 2. EXTRACTED IDENTITY DATA FIELDS ---
              const Text(
                'Verified Identity Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Full Name (from ID)',
                  prefixIcon: Icon(Icons.person_outline),
                  suffixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth (YYYY-MM-DD)',
                  prefixIcon: Icon(Icons.cake_outlined),
                  suffixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your birth date.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _genderController,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_outlined),
                  suffixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _idNumberController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Government ID Number',
                  prefixIcon: Icon(Icons.badge_outlined),
                  suffixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your ID number.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // --- 3. SUBMIT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFinalVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Confirm & Submit Verification',
                          style: TextStyle(
                            fontSize: 16,
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

  Widget _buildImagePreview({required String label, required String path}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
