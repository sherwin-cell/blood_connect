import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import 'apply_donor_step2_screen.dart';

class ApplyDonorStep1Screen extends StatefulWidget {
  const ApplyDonorStep1Screen({super.key});

  @override
  State<ApplyDonorStep1Screen> createState() => _ApplyDonorStep1ScreenState();
}

class _ApplyDonorStep1ScreenState extends State<ApplyDonorStep1Screen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedBloodType = 'O+';
  bool _isAvailable = true;

  bool _isLoadingStatus = true;
  String? _verificationStatus;

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
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final firestoreService = context.read<FirestoreService>();

        final status = await firestoreService.getIdVerificationStatus(user.uid);

        if (mounted) {
          setState(() {
            _verificationStatus = status;
            _isLoadingStatus = false;
          });
        }
      } else {
        setState(() => _isLoadingStatus = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
      }
    }
  }

  void _nextStep() {
    if (_verificationStatus == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your ID verification is currently pending admin review. You cannot apply as a donor yet.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_verificationStatus == 'rejected') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your previous ID submission was rejected. Please update your ID verification first.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyDonorStep2Screen(
          bloodType: _selectedBloodType,
          isAvailable: _isAvailable,
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
          'Step 1: Blood & Status',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingStatus
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_verificationStatus == null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Text(
                          'Notice: You have not submitted your ID verification yet. You may proceed with your application, but admin approval requires a verified ID.',
                          style: TextStyle(color: Colors.blue, fontSize: 12.5),
                        ),
                      ),

                    if (_verificationStatus == 'pending')
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Text(
                          'Notice: Your ID verification is pending admin review. Applications are temporarily restricted.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12.5,
                          ),
                        ),
                      ),

                    if (_verificationStatus == 'rejected')
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: const Text(
                          'Notice: Your previous ID submission was rejected. Please resubmit a valid ID.',
                          style: TextStyle(color: Colors.red, fontSize: 12.5),
                        ),
                      ),

                    const Text(
                      'Your Blood Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: _selectedBloodType,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _bloodTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedBloodType = val);
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    SwitchListTile(
                      value: _isAvailable,
                      activeColor: const Color(0xFF2E7D32),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Available for Immediate Emergency Donation',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Turn off if you are currently unable or ineligible to donate.',
                      ),
                      onChanged: (val) {
                        setState(() => _isAvailable = val);
                      },
                    ),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            _verificationStatus == 'pending' ||
                                _verificationStatus == 'rejected'
                            ? null
                            : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Next: Donation History',
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
