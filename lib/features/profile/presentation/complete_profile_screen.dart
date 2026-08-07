import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../data/profile_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  final _phoneController = TextEditingController();
  final _provinceController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _barangayController = TextEditingController();

  String? _selectedBloodType;
  bool _isLoading = false;

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
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        user.phoneNumber != null &&
        user.phoneNumber!.isNotEmpty) {
      _phoneController.text = user.phoneNumber!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _provinceController.dispose();
    _municipalityController.dispose();
    _barangayController.dispose();
    super.dispose();
  }

  Future<void> _onSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Authentication session lost. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save operational contact & location data to user profile
      await _profileService.updateProfile(
        uid: user.uid,
        phoneNumber: _phoneController.text.trim(),
        bloodType: _selectedBloodType!,
        province: _provinceController.text.trim().isEmpty
            ? null
            : _provinceController.text.trim(),
        municipality: _municipalityController.text.trim().isEmpty
            ? null
            : _municipalityController.text.trim(),
        barangay: _barangayController.text.trim().isEmpty
            ? null
            : _barangayController.text.trim(),
      );

      // ProfileGate automatically routes user to Identity Verification
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to save profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Block
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.water_drop_rounded,
                          size: 48,
                          color: AppColors.primaryRed,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Complete Your Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your official identity (Name, DOB, Gender) will be verified from your ID in the next step.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Contact Information Section
                const _SectionTitle('Contact Details'),
                const SizedBox(height: 12),

                const _FieldLabel('Phone Number *'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('e.g. 09123456789'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Phone Number is required';
                    }
                    if (v.trim().length < 10) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Medical Information Section
                const _SectionTitle('Medical Details'),
                const SizedBox(height: 12),

                const _FieldLabel('Blood Type *'),
                DropdownButtonFormField<String>(
                  value: _selectedBloodType,
                  decoration: _inputDecoration('Select Blood Type'),
                  items: _bloodTypes
                      .map((bt) => DropdownMenuItem(value: bt, child: Text(bt)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedBloodType = val),
                  validator: (v) => v == null ? 'Blood Type is required' : null,
                ),
                const SizedBox(height: 28),

                // Address Section
                const _SectionTitle('Address'),
                const SizedBox(height: 12),

                const _FieldLabel('Province *'),
                TextFormField(
                  controller: _provinceController,
                  decoration: _inputDecoration('e.g. Sorsogon'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Province is required'
                      : null,
                ),
                const SizedBox(height: 16),

                const _FieldLabel('Municipality / City *'),
                TextFormField(
                  controller: _municipalityController,
                  decoration: _inputDecoration('e.g. Gubat'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Municipality is required'
                      : null,
                ),
                const SizedBox(height: 16),

                const _FieldLabel('Barangay *'),
                TextFormField(
                  controller: _barangayController,
                  decoration: _inputDecoration('e.g. Manook'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Barangay is required'
                      : null,
                ),
                const SizedBox(height: 36),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSaveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Save & Proceed to Verification',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.black.withOpacity(0.35)),
      filled: true,
      fillColor: Colors.black.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }
}
