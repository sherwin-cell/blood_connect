import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/verification_provider.dart';
import 'selfie_screen.dart';

class ReviewIdScreen extends StatefulWidget {
  const ReviewIdScreen({super.key});

  @override
  State<ReviewIdScreen> createState() => _ReviewIdScreenState();
}

class _ReviewIdScreenState extends State<ReviewIdScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers to manage and edit the extracted text
  late TextEditingController _nameController;
  late TextEditingController _idNumberController;

  @override
  void initState() {
    super.initState();
    // 1. Initialize controllers with the existing OCR data from the Provider
    final provider = Provider.of<VerificationProvider>(context, listen: false);
    _nameController = TextEditingController(text: provider.data.extractedName);
    _idNumberController = TextEditingController(text: provider.data.idNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  void _confirmDetails() {
    // 2. Validate user corrections
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<VerificationProvider>(context, listen: false);

    // 3. Update the provider's VerificationData with any manual corrections
    provider.updateExtractedData(
      correctedName: _nameController.text.trim().toUpperCase(),
      correctedIdNumber: _idNumberController.text.trim(),
    );

    // 4. Navigate to the next step: Live Selfie capture.
    // Hand off the SAME provider instance (with idImagePath, extractedName,
    // idNumber already populated) rather than letting SelfieScreen create
    // its own — otherwise Provider.of<VerificationProvider>() inside
    // SelfieScreen will throw ProviderNotFoundException.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const SelfieScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access the current verification data without listening to updates
    final verificationData = context.read<VerificationProvider>().data;

    // Check for extreme case where no ID image was passed
    if (verificationData.idImagePath == null) {
      return const Scaffold(
        body: Center(child: Text("Error: No ID image found.")),
      );
    }

    final imageFile = File(verificationData.idImagePath!);

    return Scaffold(
      appBar: AppBar(title: const Text('Review Extracted Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 5. Instruction Text
              const Text(
                'Please verify that the details below match the ID card you just captured. You can edit any field if the AI scan was inaccurate.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),

              // 6. Display Captured ID Image (Confirmation UX)
              Center(
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Captured ID Photo',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              const SizedBox(height: 32),

              // 7. Dynamic Data Fields (TextFields populated by OCR)

              // Full Name (Extracted from ID)
              TextFormField(
                controller: _nameController,
                textCapitalization:
                    TextCapitalization.characters, // Auto-uppercase
                decoration: const InputDecoration(
                  labelText: 'Full Name on ID',
                  helperText:
                      'Correct capitalization and spacing are important.',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the name exactly as it appears on the ID.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ID Number (Extracted from ID)
              TextFormField(
                controller: _idNumberController,
                keyboardType:
                    TextInputType.text, // Depends on ID type (some use letters)
                decoration: const InputDecoration(
                  labelText: 'ID Number',
                  helperText:
                      'Include letters, hyphens, or spaces exactly as shown.',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the ID number.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 48),

              // 8. Confirm Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _confirmDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Details are correct, proceed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Optionally allow user to retake photo if OCR failed entirely
              Center(
                child: TextButton(
                  onPressed: () {
                    // Navigate back to the capture screen
                    Navigator.pop(context);
                  },
                  child: const Text('ID unclear? Retake photo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
