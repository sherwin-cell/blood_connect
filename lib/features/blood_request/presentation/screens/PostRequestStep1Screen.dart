import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'PostRequestStep2Screen.dart';
import '../widgets/step_indicator.dart';

class PostRequestStep1Screen extends StatefulWidget {
  const PostRequestStep1Screen({super.key});

  @override
  State<PostRequestStep1Screen> createState() => _PostRequestStep1ScreenState();
}

class _PostRequestStep1ScreenState extends State<PostRequestStep1Screen> {
  final _formKey = GlobalKey<FormState>();

  final _patientNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bdayController = TextEditingController();
  final _contactController = TextEditingController();
  final _relativeNameController = TextEditingController();

  String _selectedSex = 'Male';
  final List<String> _sexOptions = ['Male', 'Female', 'Other'];

  String _selectedRelationship = 'Family Member';
  final List<String> _relationships = [
    'Family Member',
    'Relative',
    'Friend',
    'Self',
    'Other',
  ];

  @override
  void dispose() {
    _patientNameController.dispose();
    _ageController.dispose();
    _bdayController.dispose();
    _contactController.dispose();
    _relativeNameController.dispose();
    super.dispose();
  }

  // Helper method to show Date Picker for Birthday without the pencil icon
  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 25),
      ), // Default ~25 yrs ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode
          .calendarOnly, // Removes the pencil input-mode toggle
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
        // Format as YYYY-MM-DD
        _bdayController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

        // Auto calculate age if birthday is picked
        final age = DateTime.now().year - picked.year;
        _ageController.text = age.toString();
      });
    }
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostRequestStep2Screen(
          patientName: _patientNameController.text.trim(),
          patientAge: int.parse(_ageController.text.trim()),
          patientBirthday: _bdayController.text.trim(),
          patientSex: _selectedSex,
          contactNumber: _contactController.text.trim(),
          relativeName: _relativeNameController.text.trim(),
          relationship: _selectedRelationship,
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
          'Apply for Blood Request',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryRed,
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
              // Clean Shared Circular Step Indicator for Step 1
              const StepIndicator(currentStep: 1),
              const SizedBox(height: 16),

              // Top Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person,
                      color: AppColors.primaryRed,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Patient Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryRed,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Provide complete patient and contact credentials.',
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
              const Text(
                'Personal & Contact Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Form Card Container
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
                    // 1. Patient Name
                    TextFormField(
                      controller: _patientNameController,
                      decoration: _inputDecoration(
                        'Patient Name (Surname, First, Middle)',
                        Icons.person_outline,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Please enter patient full name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Row for Age & Sex
                    Row(
                      children: [
                        // 2. Age
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              'Age',
                              Icons.cake_outlined,
                            ),
                            validator: (val) =>
                                val == null || int.tryParse(val) == null
                                ? 'Valid age required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 4. Sex
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _selectedSex,
                            decoration: _inputDecoration(
                              'Sex',
                              Icons.wc_outlined,
                            ),
                            items: _sexOptions
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedSex = val ?? 'Male'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Birthday
                    TextFormField(
                      controller: _bdayController,
                      readOnly: true,
                      onTap: () => _selectBirthday(context),
                      decoration: _inputDecoration(
                        'Birthday (YYYY-MM-DD)',
                        Icons.calendar_today_rounded,
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please select birthday'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // 5. Contact Number
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        'Contact Number',
                        Icons.phone_outlined,
                      ),
                      validator: (val) => val == null || val.length < 7
                          ? 'Enter valid contact number'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // 6. Name of Relative / Relationship Section
                    const Divider(height: 24),
                    const Text(
                      'Representative / Relative Information',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _relativeNameController,
                      decoration: _inputDecoration(
                        'Name of Relative / Contact Person',
                        Icons.badge_outlined,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Enter relative/contact name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedRelationship,
                      decoration: _inputDecoration(
                        'Relationship to Patient',
                        Icons.group_outlined,
                      ),
                      items: _relationships
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (val) => setState(
                        () => _selectedRelationship = val ?? 'Family Member',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ensure patient details match official medical records for smooth coordination.',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Next Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Next: Blood Details',
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
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
      prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 20),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
