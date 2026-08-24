import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../screens/PostRequestStep3Screen.dart';

class PostRequestStep2Screen extends StatefulWidget {
  final String bloodType;
  final int unitsRequired;
  final String urgency;
  final DateTime neededByDate;

  const PostRequestStep2Screen({
    super.key,
    required this.bloodType,
    required this.unitsRequired,
    required this.urgency,
    required this.neededByDate,
  });

  @override
  State<PostRequestStep2Screen> createState() => _PostRequestStep2ScreenState();
}

class _PostRequestStep2ScreenState extends State<PostRequestStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _patientController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _patientController.dispose();
    _hospitalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostRequestStep3Screen(
          bloodType: widget.bloodType,
          unitsRequired: widget.unitsRequired,
          urgency: widget.urgency,
          neededByDate: widget.neededByDate,
          patientName: _patientController.text.trim(),
          hospitalLocation: _hospitalController.text.trim(),
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
          'Step 2: Patient & Location',
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
              TextFormField(
                controller: _patientController,
                decoration: _inputDecoration('Patient Name', Icons.person),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter patient name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hospitalController,
                decoration: _inputDecoration(
                  'Hospital / Location',
                  Icons.local_hospital,
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter hospital name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: _inputDecoration(
                  'Additional Notes (Optional)',
                  Icons.notes,
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
                    'Next: Contact & Review',
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
