import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import './PostRequestStep3Screen.dart';

class PostRequestStep2Screen extends StatefulWidget {
  final String patientName;
  final int patientAge;
  final String relationship;

  const PostRequestStep2Screen({
    super.key,
    required this.patientName,
    required this.patientAge,
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
  String? _selectedComponent;
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
  final List<String> _unitsOptions = ['1', '2', '3', '4', '5', '6+'];
  final List<String> _components = [
    'Whole Blood',
    'Red Blood Cells',
    'Platelets',
    'Plasma',
  ];

  @override
  void dispose() {
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
          relationship: widget.relationship,
          bloodType: _anyBloodType ? 'Any Type' : _selectedBloodType!,
          unitsRequired: int.tryParse(_selectedUnits!.replaceAll('+', '')) ?? 1,
          component: _selectedComponent ?? 'Whole Blood',
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
          'Post Blood Request',
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
              // Step Indicator Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    '1\nPatient Info',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Expanded(
                    child: Divider(thickness: 2, indent: 8, endIndent: 8),
                  ),
                  Text(
                    '2\nBlood Details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryRed,
                    ),
                  ),
                  Expanded(
                    child: Divider(thickness: 2, indent: 8, endIndent: 8),
                  ),
                  Text(
                    '3\nHospital Info',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Expanded(
                    child: Divider(thickness: 2, indent: 8, endIndent: 8),
                  ),
                  Text(
                    '4\nReview & Submit',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
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
                            'Blood Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryRed,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Provide the specific blood requirements to help us find the most compatible donors.',
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
                'Blood Requirements',
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
                    // Blood Type Needed
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

                    // Don't know the blood type banner
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
                            'Don\'t know the blood type?',
                            style: TextStyle(
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'You can select "Any Type" and we\'ll find the most compatible donors.',
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
                                      if (_anyBloodType)
                                        _selectedBloodType = null;
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

                    // Units Needed
                    DropdownButtonFormField<String>(
                      value: _selectedUnits,
                      decoration: _inputDecoration(
                        'Units Needed',
                        Icons.calendar_today_outlined,
                      ), // Using calendar icon placeholder or list style matching design
                      hint: const Text('Select number of units'),
                      items: _unitsOptions
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedUnits = val),
                    ),
                    const SizedBox(height: 16),

                    // Components
                    DropdownButtonFormField<String>(
                      value: _selectedComponent,
                      decoration: _inputDecoration(
                        'Components (Optional)',
                        Icons.local_florist_outlined,
                      ),
                      hint: const Text('Select component if needed'),
                      items: _components
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedComponent = val),
                    ),
                    const SizedBox(height: 16),

                    // Special Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: 'Special Notes (Optional)',
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.primaryRed,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: const TextStyle(fontSize: 12),
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
                        'The more accurate your details, the easier it is for us to find the right donors.',
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
