import 'package:flutter/material.dart';

import '../../domain/entities/request_id_verification_data.dart';

class RequestIdSummaryCard extends StatelessWidget {
  final RequestIdVerificationData data;
  final VoidCallback onRecapture;

  const RequestIdSummaryCard({
    super.key,
    required this.data,
    required this.onRecapture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Valid ID captured',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(onPressed: onRecapture, child: const Text('Retake')),
            ],
          ),
          const SizedBox(height: 4),
          Text('Type: ${data.idType ?? '—'}'),
        ],
      ),
    );
  }
}
