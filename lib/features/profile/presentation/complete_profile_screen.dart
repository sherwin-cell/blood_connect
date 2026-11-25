import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/profile_service.dart';
import '../domain/birthday.dart';
import '../domain/sorsogon_locations.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _purokController = TextEditingController();

  // Dropdown Selections
  String _selectedNationality = 'Filipino'; // Default selection
  final String _selectedProvince = sorsogonProvince;
  String? _selectedMunicipality;
  String? _selectedBarangay;

  bool _isLoading = false;

  /// Date of Birth saved at Sign Up. When set, it is shown read-only and
  /// never re-sent; when null (Google / legacy account) the user enters it
  /// here once.
  DateTime? _savedBirthDate;
  bool _isLoadingBirthday = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _phoneController.text = user.phoneNumber!;
      }
      _loadSavedBirthday(user.uid);
    } else {
      _isLoadingBirthday = false;
    }
  }

  Future<void> _loadSavedBirthday(String uid) async {
    DateTime? saved;
    try {
      saved = await _profileService.fetchBirthday(uid);
    } catch (e) {
      debugPrint('Could not load saved birthday: $e');
    }
    if (!mounted) return;
    setState(() {
      _savedBirthDate = saved;
      if (saved != null) _birthdayController.text = Birthday.format(saved);
      _isLoadingBirthday = false;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _birthdayController.dispose();
    _purokController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    if (_savedBirthDate != null) return; // Locked: entered at sign-up.
    DateTime initialDate;

    if (_birthdayController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_birthdayController.text);
      } catch (_) {
        initialDate = DateTime.now().subtract(const Duration(days: 6570));
      }
    } else {
      initialDate = DateTime.now().subtract(const Duration(days: 6570));
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: Birthday.firstDate,
      lastDate: DateTime.now(),

      // Calendar only — removes the text/pencil entry mode
      initialEntryMode: DatePickerEntryMode.calendarOnly,

      helpText: 'SELECT DATE OF BIRTH',

      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryRed,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = Birthday.format(picked);
      });
    }
  }

  Future<void> _onSaveProfile() async {
    if (_isLoadingBirthday) return;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Authentication session lost. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _profileService.updateProfile(
        uid: user.uid,
        phoneNumber: _phoneController.text.trim(),
        // Only a legacy account without a saved birthday writes one here.
        birthday: _savedBirthDate == null
            ? Birthday.format(Birthday.parse(_birthdayController.text)!)
            : null,
        nationality: _selectedNationality,
        province: _selectedProvince,
        municipality: _selectedMunicipality,
        barangay: _selectedBarangay,
        purok: _purokController.text.trim().isEmpty
            ? null
            : _purokController.text.trim(),
      );
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header Block
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_pin_rounded,
                        size: 48,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Complete Your Profile',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please provide your details below to finalize your account setup.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Personal Details Section
                const _SectionTitle('Personal Details'),
                const SizedBox(height: 12),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Date of Birth *'),
                    if (_isLoadingBirthday)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: LinearProgressIndicator(
                          color: AppColors.primaryRed,
                        ),
                      )
                    else if (_savedBirthDate != null)
                      // Entered at sign-up: locked.
                      TextFormField(
                        key: const ValueKey('complete-profile-birthday-locked'),
                        initialValue:
                            '${Birthday.format(_savedBirthDate!)}  ·  '
                            '${Birthday.age(_savedBirthDate!)} years old',
                        enabled: false,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration('').copyWith(
                          suffixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Colors.black38,
                          ),
                          helperText: 'Entered at sign-up',
                          helperStyle: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    else
                      // Google / legacy account with no saved birthday:
                      // one-time entry.
                      TextFormField(
                        key: const ValueKey('complete-profile-birthday-input'),
                        controller: _birthdayController,
                        readOnly: true,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                        onTap: () => _selectDateOfBirth(context),
                        decoration: _inputDecoration('YYYY-MM-DD').copyWith(
                          suffixIcon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: AppColors.primaryRed,
                          ),
                          helperText:
                              'You enter this once. It cannot be changed later.',
                          helperStyle: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        validator: (v) =>
                            Birthday.validate(Birthday.parse(v ?? '')),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nationality Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Nationality *'),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedNationality,
                      dropdownColor: Colors.white,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      items: nationalityOptions.map((String nationality) {
                        return DropdownMenuItem<String>(
                          value: nationality,
                          child: Text(
                            nationality,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedNationality = newValue;
                          });
                        }
                      },
                      decoration: _inputDecoration('Select Nationality'),
                      validator: (v) =>
                          v == null ? 'Nationality is required' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Contact Information Section
                const _SectionTitle('Contact Details'),
                const SizedBox(height: 12),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Phone Number *'),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
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
                  ],
                ),
                const SizedBox(height: 28),

                // Address Section
                const _SectionTitle('Address Details'),
                const SizedBox(height: 12),

                // Province Field (Pre-filled / Fixed to Sorsogon with bold text)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Province *'),
                    TextFormField(
                      initialValue: _selectedProvince,
                      enabled: false,
                      textCapitalization: TextCapitalization.words,
                      style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      decoration: _inputDecoration('Province'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Municipality Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Municipality *'),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedMunicipality,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      hint: Text(
                        'Select Municipality',
                        style: GoogleFonts.inter(
                          color: Colors.black.withValues(alpha: 0.35),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      dropdownColor: Colors.white,
                      items: sorsogonBarangays.keys.map((String municipality) {
                        return DropdownMenuItem<String>(
                          value: municipality,
                          child: Text(
                            municipality,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedMunicipality = newValue;
                          _selectedBarangay =
                              null; // Reset barangay when municipality changes
                        });
                      },
                      decoration: _inputDecoration('Select Municipality'),
                      validator: (v) =>
                          v == null ? 'Municipality is required' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Barangay Dropdown (Depends on selected Municipality)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Barangay *'),
                    DropdownButtonFormField<String>(
                      key: ValueKey('barangay-$_selectedMunicipality'),
                      initialValue: _selectedBarangay,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      hint: Text(
                        _selectedMunicipality == null
                            ? 'Select municipality first'
                            : 'Select Barangay',
                        style: GoogleFonts.inter(
                          color: Colors.black.withValues(alpha: 0.35),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      dropdownColor: Colors.white,
                      items: _selectedMunicipality == null
                          ? []
                          : sorsogonBarangays[_selectedMunicipality]!.map((
                              String barangay,
                            ) {
                              return DropdownMenuItem<String>(
                                value: barangay,
                                child: Text(
                                  barangay,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                      onChanged: _selectedMunicipality == null
                          ? null
                          : (String? newValue) {
                              setState(() {
                                _selectedBarangay = newValue;
                              });
                            },
                      decoration: _inputDecoration('Select Barangay'),
                      validator: (v) =>
                          v == null ? 'Barangay is required' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Purok Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Purok / Street / Zone (Optional)'),
                    TextFormField(
                      controller: _purokController,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _inputDecoration('e.g. Purok 3'),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading || _isLoadingBirthday
                        ? null
                        : _onSaveProfile,
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
                        : Text(
                            'Save & Proceed to Verification',
                            style: GoogleFonts.inter(
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
      hintStyle: GoogleFonts.inter(color: Colors.black.withValues(alpha: 0.35)),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final bool isRequired = text.endsWith('*');
    final String displayText = isRequired
        ? text.substring(0, text.length - 1).trim()
        : text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: displayText,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
          children: [
            if (isRequired)
              TextSpan(
                text: ' *',
                style: GoogleFonts.inter(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
