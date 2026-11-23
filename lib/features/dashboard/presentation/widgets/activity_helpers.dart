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

/// Asks the user to confirm a destructive action; true when confirmed.
Future<bool> confirmActivityAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
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
