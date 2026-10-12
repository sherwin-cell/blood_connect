import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../donor/presentation/widgets/step_indicator.dart';
import 'apply_donor_step2_screen.dart';

class ApplyDonorStep1Screen extends StatefulWidget {
  const ApplyDonorStep1Screen({super.key});

  @override
  State<ApplyDonorStep1Screen> createState() => _ApplyDonorStep1ScreenState();
}

class _ApplyDonorStep1ScreenState extends State<ApplyDonorStep1Screen> {
  static const Color donorGreen = Color(0xFF2E7D32);

  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _ageController = TextEditingController();

  String? _civilStatusValue;
  String? _sexValue;
  String? _nationalityValue = 'Filipino';
  String? _religionValue;
  String? _educationValue;
  String? _occupationValue;

  final _permAddressController = TextEditingController();
  final _officeAddressController = TextEditingController(
    text:
        'Philippine Red Cross – Sorsogon Chapter, Sorsogon City, Sorsogon Philippines',
  );

  final _telephoneController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = true;

  final List<String> _civilStatuses = [
    'Single',
    'Married',
    'Widowed',
    'Separated',
    'Divorced',
  ];
  final List<String> _sexOptions = ['Male', 'Female'];
  final List<String> _nationalities = [
    'Filipino',
    'American',
    'Chinese',
    'Japanese',
    'Other',
  ];
  final List<String> _religions = [
    'Roman Catholic',
    'Islam',
    'Iglesia ni Cristo',
    'Christian',
    'Buddhism',
    'Other',
  ];
  final List<String> _educationLevels = [
    'Elementary',
    'High School',
    'Vocational',
    'College Undergraduate',
    'College Graduate',
    'Post Graduate',
  ];
  final List<String> _occupations = [
    'Employed',
    'Self-Employed',
    'Unemployed',
    'Student',
    'Retired',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        _emailController.text = user.email ?? '';

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;

          final firstName = data['firstName'] ?? '';
          final lastName = data['lastName'] ?? '';
          final middleName = data['middleName'] ?? '';

          _fullNameController.text = [
            firstName,
            middleName,
            lastName,
          ].where((e) => e.isNotEmpty).join(' ');

          _mobileController.text = data['mobileNo'] ?? user.phoneNumber ?? '';
          _permAddressController.text = data['permanentAddress'] ?? '';

          final savedOccupation = data['occupation'] ?? '';
          if (_occupations.contains(savedOccupation)) {
            _occupationValue = savedOccupation;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _birthdayController.dispose();
    _ageController.dispose();
    _permAddressController.dispose();
    _officeAddressController.dispose();
    _telephoneController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: donorGreen,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthdayController.text =
            '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
        _ageController.text = _calculateAge(picked).toString();
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;

    final personalData = {
      'fullName': _fullNameController.text.trim(),
      'birthday': _birthdayController.text.trim(),
      'age': _ageController.text.trim(),
      'civilStatus': _civilStatusValue ?? '',
      'sex': _sexValue ?? '',
      'permanentAddress': _permAddressController.text.trim(),
      'officeAddress': _officeAddressController.text.trim(),
      'nationality': _nationalityValue ?? '',
      'religion': _religionValue ?? '',
      'education': _educationValue ?? '',
      'occupation': _occupationValue ?? '',
      'telephone': _telephoneController.text.trim(),
      'mobileNo': _mobileController.text.trim(),
      'email': _emailController.text.trim(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyDonorStep2Screen(personalData: personalData),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        showCursor: !readOnly,
        enableInteractiveSelection: !readOnly,
        onTap: onTap,
        validator: required
            ? (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Required field';
                }
                return null;
              }
            : null,
        decoration: _inputDecoration(label).copyWith(suffixIcon: suffixIcon),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: required
            ? (v) => v == null || v.isEmpty ? 'Required field' : null
            : null,
        decoration: _inputDecoration(label),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
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
        borderSide: const BorderSide(color: donorGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _buildSectionBanner({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: donorGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: donorGreen.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: donorGreen, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: donorGreen,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: donorGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DonorStepIndicator(currentStep: 1),
                    const SizedBox(height: 16),
                    _buildSectionBanner(
                      icon: Icons.person_outline,
                      title: 'Personal Information',
                      subtitle:
                          'Provide your personal details for donor registration.',
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Personal Details'),
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
                          _buildTextField(
                            _fullNameController,
                            'Full Name (First Middle Last)',
                          ),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildTextField(
                                  _birthdayController,
                                  'Birthday (MM/DD/YYYY)',
                                  readOnly: true,
                                  onTap: () => _selectBirthday(context),
                                  suffixIcon: const Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: donorGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 1,
                                child: _buildTextField(
                                  _ageController,
                                  'Age',
                                  readOnly: true,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Civil Status',
                                  value: _civilStatusValue,
                                  items: _civilStatuses,
                                  onChanged: (val) =>
                                      setState(() => _civilStatusValue = val),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Sex',
                                  value: _sexValue,
                                  items: _sexOptions,
                                  onChanged: (val) =>
                                      setState(() => _sexValue = val),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildSectionTitle('Address Information'),
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
                          _buildTextField(
                            _permAddressController,
                            'Permanent Address (No/Street/Barangay/Town/Province/Zip)',
                          ),
                          _buildTextField(
                            _officeAddressController,
                            'Office Address',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildSectionTitle('Background & Contact'),
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Nationality',
                                  value: _nationalityValue,
                                  items: _nationalities,
                                  onChanged: (val) =>
                                      setState(() => _nationalityValue = val),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Religion',
                                  value: _religionValue,
                                  items: _religions,
                                  required: false,
                                  onChanged: (val) =>
                                      setState(() => _religionValue = val),
                                ),
                              ),
                            ],
                          ),

                          _buildDropdownField(
                            label: 'Education',
                            value: _educationValue,
                            items: _educationLevels,
                            onChanged: (val) =>
                                setState(() => _educationValue = val),
                          ),

                          _buildDropdownField(
                            label: 'Occupation',
                            value: _occupationValue,
                            items: _occupations,
                            onChanged: (val) =>
                                setState(() => _occupationValue = val),
                          ),

                          _buildTextField(
                            _telephoneController,
                            'Telephone No.',
                            required: false,
                            keyboardType: TextInputType.phone,
                          ),
                          _buildTextField(
                            _mobileController,
                            'Mobile No.',
                            keyboardType: TextInputType.phone,
                          ),
                          _buildTextField(
                            _emailController,
                            'Email Address',
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
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
                              'Please make sure your information is accurate. These details will be used for donor registration and coordination.',
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
                              'Next: Blood Type & History',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 18,
                            ),
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
