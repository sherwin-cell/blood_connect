import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../domain/entities/request_id_verification_data.dart';
import '../domain/repositories/i_verification_repository.dart';
import 'provider/request_id_verification_provider.dart';
import 'screens/select_valid_id_screen.dart';

/// Reusable government-ID capture flow for any request/application form.
///
/// Returns [RequestIdVerificationData] with local image paths. The calling
/// form uploads images and attaches them when the request is submitted.
class IdVerificationFlow {
  static const String routeName = '/id-verification';

  static Future<RequestIdVerificationData?> start(BuildContext context) async {
    final repository = context.read<IVerificationRepository>();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No authenticated user found. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    return Navigator.of(context).push<RequestIdVerificationData>(
      MaterialPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (_) => ChangeNotifierProvider(
          create: (_) => RequestIdVerificationProvider(
            repository: repository,
            userId:
                user.uid, // Resolved hardcoded placeholder issue (BC-BUG-001)
          ),
          child: const SelectValidIdScreen(),
        ),
      ),
    );
  }

  static void complete(BuildContext context, RequestIdVerificationData data) {
    Navigator.of(context).popUntil((route) => route.settings.name == routeName);
    Navigator.of(context).pop(data);
  }
}
