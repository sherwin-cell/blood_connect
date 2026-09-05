import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../provider/verification_provider.dart';
import 'select_valid_id_screen.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;

  String? _selectedGender;
  final List<String> _genderOptions = ['Male', 'Female'];

  String? _selectedBloodType;
  final List<String> _bloodTypeOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dobController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        final barangay = data['barangay'] ?? '';
        final municipality = data['municipality'] ?? '';
        final province = data['province'] ?? '';
        final fullAddress = [
          barangay,
          municipality,
          province,
        ].where((e) => e.toString().isNotEmpty).join(', ');

        setState(() {
          _nameController.text = data['fullName'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _addressController.text = fullAddress.isNotEmpty
              ? fullAddress
              : (data['address'] ?? '');

          final dbGender = data['gender']?.toString();
          if (dbGender != null && _genderOptions.contains(dbGender)) {
            _selectedGender = dbGender;
          } else {
            _selectedGender = null;
          }

          final dbBloodType = data['bloodType']?.toString();
          if (dbBloodType != null && _bloodTypeOptions.contains(dbBloodType)) {
            _selectedBloodType = dbBloodType;
          } else {
            _selectedBloodType = null;
          }

          final rawDob = data['birthDate'];
          if (rawDob != null && rawDob.toString().isNotEmpty) {
            _dobController.text = _formatDateString(rawDob.toString());
          } else {
            _dobController.text = '';
          }

          _isLoadingProfile = false;
        });
        return;
      }
    }
    setState(() => _isLoadingProfile = false);
  }

  String _formatDateString(String dateStr) {
    try {
      final parsedDate = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    DateTime initialDate = DateTime.now().subtract(
      const Duration(days: 365 * 20),
    );
    try {
      if (_dobController.text.isNotEmpty) {
        initialDate = DateFormat('yyyy-MM-dd').parse(_dobController.text);
      }
    } catch (_) {}

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFC62828),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onContinuePressed() {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<VerificationProvider>();
      provider.updatePersonalDetails(
        fullName: _nameController.text.trim(),
        birthDate: _dobController.text.trim(),
        gender: _selectedGender ?? '',
        bloodType: _selectedBloodType ?? '',
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const SelectValidIdScreen(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Personal Details',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFC62828)),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verify your profile information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Review auto-filled fields or complete any missing details below.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          physics: const ClampingScrollPhysics(),
                          children: [
                            _buildTextField(
                              'Full Name',
                              _nameController,
                              'Please enter your full name',
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => _selectDateOfBirth(context),
                              child: AbsorbPointer(
                                child: _buildTextField(
                                  'Date of Birth (YYYY-MM-DD)',
                                  _dobController,
                                  'Please select your date of birth',
                                  suffixIcon: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: InputDecoration(
                                labelText: 'Sex / Gender',
                                labelStyle: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFC62828),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              items: _genderOptions.map((String gender) {
                                return DropdownMenuItem<String>(
                                  value: gender,
                                  child: Text(
                                    gender,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedGender = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select your sex/gender';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            // Blood Type Dropdown Field
                            DropdownButtonFormField<String>(
                              value: _selectedBloodType,
                              decoration: InputDecoration(
                                labelText: 'Blood Type',
                                labelStyle: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFC62828),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              items: _bloodTypeOptions.map((String bloodType) {
                                return DropdownMenuItem<String>(
                                  value: bloodType,
                                  child: Text(
                                    bloodType,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedBloodType = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select your blood type';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(
                              'Address',
                              _addressController,
                              'Please enter your address',
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(
                              'Contact Number',
                              _phoneController,
                              'Please enter your contact number',
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _onContinuePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue to ID Submission',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        'Step 1 of 7',
                        style: TextStyle(fontSize: 10.5, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String errorMsg, {
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.black54),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return errorMsg;
        }
        return null;
      },
    );
  }
}
