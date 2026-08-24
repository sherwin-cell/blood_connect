import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';

class PostRequestStep3Screen extends StatefulWidget {
  final String bloodType;
  final int unitsRequired;
  final String urgency;
  final DateTime neededByDate;
  final String patientName;
  final String hospitalLocation;
  final String notes;

  const PostRequestStep3Screen({
    super.key,
    required this.bloodType,
    required this.unitsRequired,
    required this.urgency,
    required this.neededByDate,
    required this.patientName,
    required this.hospitalLocation,
    required this.notes,
  });

  @override
  State<PostRequestStep3Screen> createState() => _PostRequestStep3ScreenState();
}

class _PostRequestStep3ScreenState extends State<PostRequestStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _contactPersonController = TextEditingController();
  final _contactController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contactPersonController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      await FirebaseFirestore.instance.collection('blood_requests').add({
        'userId': user.uid,
        'bloodType': widget.bloodType,
        'unitsRequired': widget.unitsRequired,
        'urgency': widget.urgency,
        'neededByDate': Timestamp.fromDate(widget.neededByDate),
        'patientName': widget.patientName,
        'hospitalLocation': widget.hospitalLocation,
        'notes': widget.notes,
        'contactPerson': _contactPersonController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Blood request submitted! Waiting for PRC admin review.',
          ),
          backgroundColor:
              Colors.orange, // Use orange/amber for 'pending' state
        ),
      );

      // Pop back to root/home screen
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate =
        '${widget.neededByDate.month}/${widget.neededByDate.day}/${widget.neededByDate.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Step 3: Contact & Review',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _contactPersonController,
                decoration: _inputDecoration(
                  'Contact Person Name',
                  Icons.badge,
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter contact person' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  'Contact Phone Number',
                  Icons.phone,
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter phone number' : null,
              ),
              const SizedBox(height: 24),

              // REVIEW REQUEST CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REVIEW REQUEST',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryRed,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(height: 20),
                    Text('Blood Type: ${widget.bloodType}'),
                    Text('Units: ${widget.unitsRequired}'),
                    Text('Urgency: ${widget.urgency}'),
                    Text('Date Needed: $formattedDate'),
                    Text('Patient: ${widget.patientName}'),
                    Text('Hospital: ${widget.hospitalLocation}'),
                    if (widget.notes.isNotEmpty) Text('Notes: ${widget.notes}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Publish Request',
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
