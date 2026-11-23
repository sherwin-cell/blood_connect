import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/profile_repository.dart';
import '../domain/sorsogon_locations.dart';
import '../domain/user_profile_model.dart';

const _red = Color(0xFFC62828);
const _softRed = Color(0xFFFDECEC);
const _border = Color(0xFFEDEDED);

/// Philippine mobile number: 09XXXXXXXXX or +639XXXXXXXXX (spaces and
/// dashes ignored). Returns an error message or null.
String? validatePhilippineMobile(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
  if (digits.isEmpty) return 'Contact number is required';
  if (!RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(digits)) {
    return 'Enter a valid mobile number, e.g. 09123456789';
  }
  return null;
}

String? validateFullName(String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return 'Full name is required';
  if (name.length < 2) return 'Enter your full name';
  return null;
}

/// Edits the user's own profile. Writes only [PersonalInfoUpdate]'s fields
/// (plus `photoUrl`), which the owner update rule allows.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.repository,
    this.pickPhoto,
    this.today,
  });

  final UserProfile profile;
  final ProfileRepository repository;

  /// Test hook; defaults to the image picker.
  final Future<File?> Function(BuildContext context)? pickPhoto;

  /// Test hook for the date picker's last date.
  final DateTime? today;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.profile.fullName,
  );
  late final _phoneController = TextEditingController(
    text: widget.profile.phoneNumber,
  );
  late final _purokController = TextEditingController(
    text: widget.profile.purok ?? '',
  );

  late DateTime? _birthDate = widget.profile.birthDate;
  late String? _gender = _blankToNull(widget.profile.gender);
  late String? _nationality = _blankToNull(widget.profile.nationality);
  late String? _municipality = _blankToNull(widget.profile.municipality);
  late String? _barangay = _blankToNull(widget.profile.barangay);

  File? _newPhoto;
  bool _saving = false;

  static String? _blankToNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _purokController.dispose();
    super.dispose();
  }

  /// Dropdown items, keeping a saved value that is not in the list (older
  /// data) so the dropdown does not fail.
  static List<String> _withCurrent(Iterable<String> options, String? current) =>
      [...options, if (current != null && !options.contains(current)) current];

  Future<File?> _defaultPickPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return picked == null ? null : File(picked.path);
  }

  Future<void> _changePhoto() async {
    final file = await (widget.pickPhoto ?? _defaultPickPhoto)(context);
    if (file != null && mounted) setState(() => _newPhoto = file);
  }

  Future<void> _pickBirthDate() async {
    final today = widget.today ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'SELECT DATE OF BIRTH',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final uid = widget.profile.uid;
    try {
      if (_newPhoto != null) {
        await widget.repository.updateProfilePhoto(uid, _newPhoto!);
      }
      await widget.repository.updatePersonalInfo(
        uid,
        PersonalInfoUpdate(
          fullName: _nameController.text,
          phoneNumber: _phoneController.text.replaceAll(RegExp(r'[\s-]'), ''),
          birthDate: _birthDate,
          gender: _gender,
          nationality: _nationality,
          purok: _purokController.text,
          barangay: _barangay,
          municipality: _municipality,
          province: sorsogonProvince,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save your profile: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _decoration(String hint, {IconData? icon}) => InputDecoration(
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _red),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
  );

  Widget _dropdown({
    required String label,
    required String hint,
    required String? value,
    required List<String> options,
    required ValueChanged<String?>? onChanged,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        DropdownButtonFormField<String>(
          // Rebuild when the options change (barangays follow municipality).
          key: ValueKey('$label|${options.length}|$value'),
          initialValue: value,
          isExpanded: true,
          decoration: _decoration(hint, icon: icon),
          items: [
            for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: _saving ? null : onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.profile.avatarUrl;
    final ImageProvider? image = _newPhoto != null
        ? FileImage(_newPhoto!)
        : avatar != null
        ? NetworkImage(avatar)
        : null;
    final municipalities = _withCurrent(sorsogonBarangays.keys, _municipality);
    final barangays = _withCurrent(
      sorsogonBarangays[_municipality] ?? const <String>[],
      _barangay,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: _softRed,
                    backgroundImage: image,
                    child: image == null
                        ? const Icon(Icons.person, size: 52, color: _red)
                        : null,
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _changePhoto,
                    style: TextButton.styleFrom(foregroundColor: _red),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Change Profile Picture'),
                  ),
                ],
              ),
            ),
            _label('Full Name'),
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(
                'Juan Dela Cruz',
                icon: Icons.person_outline,
              ),
              validator: validateFullName,
            ),
            _label('Date of Birth'),
            InkWell(
              onTap: _saving ? null : _pickBirthDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _decoration(
                  'Select date',
                  icon: Icons.cake_outlined,
                ).copyWith(suffixIcon: const Icon(Icons.calendar_today)),
                child: Text(
                  _birthDate == null
                      ? 'Select date'
                      : DateFormat('MMMM d, yyyy').format(_birthDate!),
                  style: TextStyle(
                    color: _birthDate == null ? Colors.black45 : Colors.black87,
                  ),
                ),
              ),
            ),
            _dropdown(
              label: 'Gender',
              hint: 'Select gender',
              icon: Icons.wc_outlined,
              value: _gender,
              options: _withCurrent(genderOptions, _gender),
              onChanged: (v) => setState(() => _gender = v),
            ),
            _dropdown(
              label: 'Nationality',
              hint: 'Select nationality',
              icon: Icons.flag_outlined,
              value: _nationality,
              options: _withCurrent(nationalityOptions, _nationality),
              onChanged: (v) => setState(() => _nationality = v),
            ),
            _label('Contact Number'),
            TextFormField(
              controller: _phoneController,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              decoration: _decoration(
                '09123456789',
                icon: Icons.phone_outlined,
              ),
              validator: validatePhilippineMobile,
            ),
            _label('Email Address'),
            TextFormField(
              initialValue: widget.profile.email,
              readOnly: true,
              enabled: false,
              decoration: _decoration(
                '',
                icon: Icons.email_outlined,
              ).copyWith(helperText: 'Your sign-in email cannot be changed.'),
            ),
            const SizedBox(height: 8),
            const Divider(height: 24),
            const Text(
              'Address',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            _label('Purok / Street'),
            TextFormField(
              controller: _purokController,
              enabled: !_saving,
              decoration: _decoration('e.g. Purok 3'),
            ),
            _dropdown(
              label: 'Municipality / City',
              hint: 'Select municipality',
              value: _municipality,
              options: municipalities,
              onChanged: (v) => setState(() {
                if (v != _municipality) _barangay = null;
                _municipality = v;
              }),
            ),
            _dropdown(
              label: 'Barangay',
              hint: _municipality == null
                  ? 'Select a municipality first'
                  : 'Select barangay',
              value: _barangay,
              options: barangays,
              onChanged: _municipality == null
                  ? null
                  : (v) => setState(() => _barangay = v),
            ),
            _label('Province'),
            TextFormField(
              initialValue: sorsogonProvince,
              enabled: false,
              decoration: _decoration(''),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: _border),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
