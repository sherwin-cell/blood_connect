import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/request_id_verification_data.dart';
import '../provider/request_id_verification_provider.dart';

class ReviewIdScreen extends StatelessWidget {
  const ReviewIdScreen({super.key});

  Future<void> _confirm(BuildContext context) async {
    final provider = context.read<RequestIdVerificationProvider>();

    // Prevent submission if the captured ID is incomplete.
    if (!provider.data.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ID capture is incomplete. Please recapture a valid ID.',
          ),
        ),
      );
      return;
    }

    // Submit the ID first.
    final bool success = await provider.confirmAndSubmit();

    debugPrint('========== CONFIRM RESULT ==========');
    debugPrint('success = $success');
    debugPrint('mounted = ${context.mounted}');
    debugPrint('====================================');

    if (!context.mounted) return;

    // If submission failed, stay on the review screen.
    if (!success) {
      debugPrint('SUBMISSION FAILED');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Failed to submit ID. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint('SUBMISSION SUCCESSFUL');
    debugPrint('RETURNING RESULT TO CaptureBackIdScreen');

    // Return the completed verification data to the previous screen.
    Navigator.of(context).pop<RequestIdVerificationData>(provider.data);

    debugPrint('REVIEW SCREEN POPPED WITH RESULT');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestIdVerificationProvider>();
    final data = provider.data;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Review ID',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.idType ?? 'Government ID',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (data.frontIdImage != null)
              _imagePreview('Front of ID', data.frontIdImage!),

            if (data.backIdImage != null) ...[
              const SizedBox(height: 12),
              _imagePreview('Back of ID', data.backIdImage!),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: provider.isLoading ? null : () => _confirm(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                ),
                child: provider.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Confirm ID',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePreview(String label, String path) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),

        const SizedBox(height: 6),

        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(path),
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 140,
                width: double.infinity,
                alignment: Alignment.center,
                color: Colors.grey.shade200,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 32,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Unable to display image',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
