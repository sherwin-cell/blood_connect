import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'PostRequestStep2Screen.dart';

class PostRequestStep1Screen extends StatefulWidget {
  const PostRequestStep1Screen({super.key});

  @override
  State<PostRequestStep1Screen> createState() => _PostRequestStep1ScreenState();
}

class _PostRequestStep1ScreenState extends State<PostRequestStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedBloodType = 'O+';
  String _selectedUrgency = 'Urgent';
  final _unitsController = TextEditingController();
  DateTime? _neededByDate;

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
  final List<String> _urgencyLevels = ['Normal', 'Urgent', 'Critical'];

  @override
  void dispose() {
    _unitsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _neededByDate = picked);
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    if (_neededByDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a needed-by date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostRequestStep2Screen(
          bloodType: _selectedBloodType,
          unitsRequired: int.parse(_unitsController.text.trim()),
          urgency: _selectedUrgency,
          neededByDate: _neededByDate!,
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
          'Step 1: Blood Requirement',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedBloodType,
                decoration: _inputDecoration('Blood Type', Icons.water_drop),
                items: _bloodTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBloodType = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitsController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  'Units Required (1 - 10)',
                  Icons.format_list_numbered,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter units required';
                  }
                  final number = int.tryParse(val);
                  if (number == null) {
                    return 'Please enter a valid number';
                  }
                  if (number < 1 || number > 10) {
                    return 'Units must be between 1 and 10';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedUrgency,
                decoration: _inputDecoration(
                  'Urgency Level',
                  Icons.priority_high,
                ),
                items: _urgencyLevels
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedUrgency = val!),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _inputDecoration(
                    'Date Needed',
                    Icons.calendar_today,
                  ),
                  child: Text(
                    _neededByDate == null
                        ? 'Select Needed-By Date'
                        : '${_neededByDate!.month}/${_neededByDate!.day}/${_neededByDate!.year}',
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next: Patient & Location',
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primaryRed),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
