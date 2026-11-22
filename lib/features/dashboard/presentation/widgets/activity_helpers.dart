import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

/// Formats a Firestore date such as `neededByDate`, or null if missing.
String? formatActivityDate(dynamic value) {
  if (value is Timestamp) {
    return DateFormat('MMM d, yyyy').format(value.toDate());
  }
  return null;
}

/// Asks the user to confirm a destructive action.
///
/// Returns null when they back out, otherwise the (possibly empty) reason
/// they typed. The reason field is shown only when [withReason] is true.
Future<String?> confirmActivityAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool withReason = false,
}) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (withReason) ...[
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// Shows a green success or red error snackbar.
void showActivityResult(BuildContext context, Object? error, String success) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error == null
            ? success
            : error.toString().replaceFirst('Exception: ', ''),
      ),
      backgroundColor: error == null ? Colors.green : Colors.red,
    ),
  );
}
