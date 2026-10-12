import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import './PostRequestStep3Screen.dart';
import '../widgets/step_indicator.dart';

class PostRequestStep2Screen extends StatefulWidget {
  final String patientName;
  final int patientAge;
  final String patientBirthday;
  final String patientSex;
  final String contactNumber;
  final String relativeName;
  final String relationship;

  const PostRequestStep2Screen({
    super.key,
    required this.patientName,
    required this.patientAge,
    required this.patientBirthday,
    required this.patientSex,
    required this.contactNumber,
    required this.relativeName,
    required this.relationship,
  });

  @override
  State<PostRequestStep2Screen> createState() => _PostRequestStep2ScreenState();
}

class _PostRequestStep2ScreenState extends State<PostRequestStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBloodType = 'A+';
  bool _anyBloodType = false;
  String? _selectedUnits;
  String? _selectedComponent = 'Whole Blood';
  final _hemoglobinController = TextEditingController();
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
  final List<String> _unitsOptions = ['1', '2', '3', '4', '5', 'Others'];
  final List<String> _components = [
    'Whole Blood',
    'Red Blood Cells',
    'Platelets',
    'Plasma',
    'Cryoprecipitate',
  ];

  @override
  void dispose() {
    _hemoglobinController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_anyBloodType && _selectedBloodType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a blood type or check "Any Blood Type"'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedUnits == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select units needed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostRequestStep3Screen(
          patientName: widget.patientName,
          patientAge: widget.patientAge,
          patientBirthday: widget.patientBirthday,
          patientSex: widget.patientSex,
          contactNumber: widget.contactNumber,
          relativeName: widget.relativeName,
          relationship: widget.relationship,
          bloodType: _anyBloodType ? 'Any Type' : _selectedBloodType!,
          unitsRequired: int.tryParse(_selectedUnits!.replaceAll('+', '')) ?? 1,
          component: _selectedComponent ?? 'Whole Blood',
          hemoglobin: _hemoglobinController.text.trim(),
          urgency: 'Urgent',
          neededByDate: DateTime.now().add(const Duration(days: 1)),
          notes: _notesController.text.trim(),
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
              // Clean Shared Circular Step Indicator for Step 2
              const StepIndicator(currentStep: 2),
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
                      Icons.water_drop,
                      color: AppColors.primaryRed,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Blood Requirements',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryRed,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Specify the exact blood parameters and clinical components needed.',
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
                'Blood Details & Lab Specs',
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
                    // 1. Blood Type Needed
                    DropdownButtonFormField<String>(
                      value: _anyBloodType ? null : _selectedBloodType,
                      decoration: _inputDecoration(
                        'Blood Type Needed',
                        Icons.water_drop_outlined,
                      ),
                      hint: const Text('Select blood type'),
                      items: _bloodTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: _anyBloodType
                          ? null
                          : (val) => setState(() => _selectedBloodType = val),
                    ),
                    const SizedBox(height: 12),

                    // Don't know the blood type banner / Checkbox
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Don\'t know the exact blood type?',
                            style: TextStyle(
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Select "Any Blood Type" to broadcast to compatible profiles.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 10.5,
                            ),
                          ),
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _anyBloodType,
                                  activeColor: AppColors.primaryRed,
                                  onChanged: (val) {
                                    setState(() {
                                      _anyBloodType = val ?? false;
                                      if (_anyBloodType) {
                                        _selectedBloodType = null;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Any Blood Type',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Units Needed
                    DropdownButtonFormField<String>(
                      value: _selectedUnits,
                      decoration: _inputDecoration(
                        'Units Needed',
                        Icons.list_alt_outlined,
                      ),
                      hint: const Text('Select number of units'),
                      items: _unitsOptions
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedUnits = val),
                    ),
                    const SizedBox(height: 16),

                    // 3. Component
                    DropdownButtonFormField<String>(
                      value: _selectedComponent,
                      decoration: _inputDecoration(
                        'Blood Component',
                        Icons.science_outlined,
                      ),
                      hint: const Text('Select component type'),
                      items: _components
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedComponent = val),
                    ),
                    const SizedBox(height: 16),

                    // 4. Latest Hemoglobin / Hematocrit
                    TextFormField(
                      controller: _hemoglobinController,
                      decoration: _inputDecoration(
                        'Latest Hemoglobin / Hematocrit (e.g., 9.5 g/dL)',
                        Icons.medical_services_outlined,
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
                        'Precise component and blood specification details accelerate donor matching.',
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

              // Footer Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
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
                            'Next: Hospital Info',
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
                ],
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
