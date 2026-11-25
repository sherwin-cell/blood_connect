import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/entities/request_id_verification_data.dart';
import '../domain/repositories/i_verification_repository.dart';
import '../presentation/provider/request_id_verification_provider.dart';
import '../presentation/screens/select_valid_id_screen.dart';

/// The valid-ID step: select an ID type, capture front and back, review,
/// submit. Returns the submitted data, or null when the user backs out.
class IdVerificationFlow {
  static const String routeName = '/id-verification';

  static Future<RequestIdVerificationData?> start(BuildContext context) async {
    if (!context.mounted) return null;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue.')),
      );
      return null;
    }

    final repository = context.read<IVerificationRepository>();
    final navigator = Navigator.of(context);

    // Pushed once; the provider lives only as long as this route.
    final route = MaterialPageRoute<RequestIdVerificationData>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => ChangeNotifierProvider<RequestIdVerificationProvider>(
        create: (_) => RequestIdVerificationProvider(
          repository: repository,
          userId: user.uid,
        ),
        child: const SelectValidIdScreen(),
      ),
    );

    return navigator.push<RequestIdVerificationData>(route);
  }

  /// Ends the flow from its last screen, returning [data] to [start]'s
  /// caller. Pops only the current route.
  static void complete(BuildContext context, RequestIdVerificationData data) {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    navigator.pop<RequestIdVerificationData>(data);
  }
}
