import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../id_verification_flow.dart';
import '../provider/request_id_verification_provider.dart';

class ReviewIdScreen extends StatelessWidget {
  const ReviewIdScreen({super.key});

  void _confirm(BuildContext context) {
    final provider = context.read<RequestIdVerificationProvider>();

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

    IdVerificationFlow.complete(context, provider.confirm());
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<RequestIdVerificationProvider>().data;

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
                onPressed: () => _confirm(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm ID'),
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
          ),
        ),
      ],
    );
  }
}
