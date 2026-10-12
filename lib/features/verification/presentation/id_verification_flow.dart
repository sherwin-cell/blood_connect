import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/entities/request_id_verification_data.dart';
import '../domain/repositories/i_verification_repository.dart';
import '../presentation/provider/request_id_verification_provider.dart';
import '../presentation/screens/select_valid_id_screen.dart';

class IdVerificationFlow {
  static const String routeName = '/id-verification';

  // ============================================================
  // START ID VERIFICATION FLOW
  // ============================================================

  static Future<RequestIdVerificationData?> start(BuildContext context) async {
    debugPrint('');
    debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    debugPrint('!!! START() UNIQUE MARKER 2026-09-29-FIX !!!');
    debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

    debugPrint('START: IdVerificationFlow.start() ENTERED');
    debugPrint('START: context.mounted = ${context.mounted}');

    if (!context.mounted) {
      debugPrint('START: STOP - context is not mounted.');
      return null;
    }

    // ==========================================================
    // FIREBASE USER
    // ==========================================================

    final User? user = FirebaseAuth.instance.currentUser;

    debugPrint('');
    debugPrint('START: Firebase user exists = ${user != null}');
    debugPrint('START: Firebase UID = ${user?.uid}');

    if (user == null) {
      debugPrint('START: STOP - no authenticated Firebase user.');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to continue.')),
        );
      }

      return null;
    }

    // ==========================================================
    // GET VERIFICATION REPOSITORY
    // ==========================================================

    debugPrint('');
    debugPrint('START: Getting IVerificationRepository...');

    late final IVerificationRepository repository;

    try {
      repository = context.read<IVerificationRepository>();

      debugPrint('START: IVerificationRepository obtained successfully.');
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('START: ERROR obtaining IVerificationRepository');
      debugPrint('START ERROR: $e');
      debugPrint('');
      debugPrint('START ERROR STACK TRACE:');
      debugPrint('$stackTrace');

      rethrow;
    }

    // ==========================================================
    // GET NAVIGATOR
    // ==========================================================

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('========== START NAVIGATOR IDENTITY ===============');
    debugPrint('====================================================');

    final NavigatorState navigator = Navigator.of(context);

    debugPrint('START: Navigator obtained successfully.');
    debugPrint('START: Navigator hashCode = ${navigator.hashCode}');
    debugPrint(
      'START: Navigator canPop BEFORE push = '
      '${navigator.canPop()}',
    );
    debugPrint(
      'START: Navigator context mounted = '
      '${navigator.context.mounted}',
    );

    // ==========================================================
    // CREATE ID VERIFICATION ROUTE
    // ==========================================================

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('========== CREATE ID VERIFICATION ROUTE ===========');
    debugPrint('====================================================');

    final MaterialPageRoute<RequestIdVerificationData> route =
        MaterialPageRoute<RequestIdVerificationData>(
          settings: const RouteSettings(name: routeName),
          builder: (BuildContext routeContext) {
            debugPrint('');
            debugPrint('====================================================');
            debugPrint('========== ID VERIFICATION ROUTE BUILDER ===========');
            debugPrint('====================================================');

            debugPrint(
              'BUILDER: routeContext.mounted = '
              '${routeContext.mounted}',
            );

            final ModalRoute<dynamic>? routeInfo = ModalRoute.of(routeContext);

            debugPrint(
              'BUILDER: route name = '
              '${routeInfo?.settings.name ?? 'UNKNOWN'}',
            );

            debugPrint(
              'BUILDER: route runtimeType = '
              '${routeInfo?.runtimeType}',
            );

            debugPrint(
              'BUILDER: route hashCode = '
              '${routeInfo?.hashCode}',
            );

            debugPrint('BUILDER: Creating RequestIdVerificationProvider...');

            return ChangeNotifierProvider<RequestIdVerificationProvider>(
              create: (_) {
                debugPrint('BUILDER: Provider CREATE started.');

                final RequestIdVerificationProvider provider =
                    RequestIdVerificationProvider(
                      repository: repository,
                      userId: user.uid,
                    );

                debugPrint('BUILDER: Provider CREATED successfully.');

                return provider;
              },
              child: const SelectValidIdScreen(),
            );
          },
        );

    debugPrint('');
    debugPrint('START: MaterialPageRoute CREATED.');
    debugPrint('START: Route hashCode = ${route.hashCode}');
    debugPrint('START: Route name = ${route.settings.name}');

    // ==========================================================
    // PUSH ROUTE — ONLY ONCE
    // ==========================================================

    debugPrint('');
    debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    debugPrint('!!! ABOUT TO PUSH ID VERIFICATION ROUTE !!!');
    debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

    debugPrint('PUSH: Navigator hashCode = ${navigator.hashCode}');

    debugPrint('PUSH: Route hashCode = ${route.hashCode}');

    debugPrint('PUSH: Calling navigator.push(route)...');

    try {
      final RequestIdVerificationData? result = await navigator
          .push<RequestIdVerificationData>(route);

      // ========================================================
      // PUSH RETURNED
      // ========================================================

      debugPrint('');
      debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      debugPrint('!!! PUSH FUTURE RETURNED 2026-09-29-FIX !!!');
      debugPrint('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');

      debugPrint('RETURN: navigator.push() Future COMPLETED.');

      debugPrint('RETURN: context.mounted = ${context.mounted}');

      debugPrint('RETURN: Navigator hashCode = ${navigator.hashCode}');

      debugPrint('RETURN: result == null = ${result == null}');

      if (result == null) {
        debugPrint('RETURN: Navigator returned NULL.');
      } else {
        debugPrint('');
        debugPrint('RETURN: Verification data received.');

        debugPrint('RETURN: ID Type = ${result.idType}');

        debugPrint('RETURN: Front ID = ${result.frontIdImage}');

        debugPrint('RETURN: Back ID = ${result.backIdImage}');

        debugPrint(
          'RETURN: Validation Status = '
          '${result.validationStatus}',
        );

        debugPrint(
          'RETURN: Submitted At = '
          '${result.submittedAt}',
        );
      }

      debugPrint('');
      debugPrint('RETURN: IdVerificationFlow.start() RETURNING RESULT');

      return result;
    } catch (e, stackTrace) {
      // ========================================================
      // PUSH ERROR
      // ========================================================

      debugPrint('');
      debugPrint('====================================================');
      debugPrint('========== NAVIGATOR.PUSH ERROR ====================');
      debugPrint('====================================================');

      debugPrint('PUSH ERROR: $e');

      debugPrint('');
      debugPrint('PUSH ERROR STACK TRACE:');
      debugPrint('$stackTrace');

      rethrow;
    }
  }

  // ============================================================
  // COMPLETE ID VERIFICATION FLOW
  // ============================================================

  static void complete(BuildContext context, RequestIdVerificationData data) {
    debugPrint('');
    debugPrint('====================================================');
    debugPrint('========== FLOW COMPLETE START =====================');
    debugPrint('====================================================');

    debugPrint('COMPLETE: IdVerificationFlow.complete() ENTERED');

    debugPrint('COMPLETE: context.mounted = ${context.mounted}');

    if (!context.mounted) {
      debugPrint('COMPLETE: STOP - context is no longer mounted.');

      return;
    }

    // ==========================================================
    // GET NAVIGATOR
    // ==========================================================

    final NavigatorState navigator = Navigator.of(context);

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('========== COMPLETE NAVIGATOR IDENTITY =============');
    debugPrint('====================================================');

    debugPrint('COMPLETE: Navigator obtained successfully.');

    debugPrint(
      'COMPLETE: Navigator hashCode = '
      '${navigator.hashCode}',
    );

    debugPrint(
      'COMPLETE: Navigator canPop = '
      '${navigator.canPop()}',
    );

    debugPrint(
      'COMPLETE: Navigator context mounted = '
      '${navigator.context.mounted}',
    );

    // ==========================================================
    // CURRENT ROUTE
    // ==========================================================

    final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('========== CURRENT ROUTE ===========================');
    debugPrint('====================================================');

    debugPrint(
      'COMPLETE: Current route name = '
      '${currentRoute?.settings.name ?? 'UNKNOWN'}',
    );

    debugPrint(
      'COMPLETE: Current route runtimeType = '
      '${currentRoute?.runtimeType}',
    );

    debugPrint(
      'COMPLETE: Current route hashCode = '
      '${currentRoute?.hashCode}',
    );

    // ==========================================================
    // RETURNED DATA
    // ==========================================================

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('========== VERIFICATION DATA =======================');
    debugPrint('====================================================');

    debugPrint('COMPLETE: ID Type = ${data.idType}');

    debugPrint('COMPLETE: Front ID = ${data.frontIdImage}');

    debugPrint('COMPLETE: Back ID = ${data.backIdImage}');

    debugPrint(
      'COMPLETE: Validation Status = '
      '${data.validationStatus}',
    );

    debugPrint(
      'COMPLETE: Submitted At = '
      '${data.submittedAt}',
    );

    // ==========================================================
    // CHECK NAVIGATOR
    // ==========================================================

    if (!navigator.canPop()) {
      debugPrint('');
      debugPrint('COMPLETE: STOP - Navigator cannot pop.');

      return;
    }

    // ==========================================================
    // POP ONLY THE CURRENT ROUTE
    // ==========================================================

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('========== CALLING NAVIGATOR.POP ==================');
    debugPrint('====================================================');

    debugPrint(
      'POP: Navigator hashCode = '
      '${navigator.hashCode}',
    );

    debugPrint(
      'POP: Current route hashCode = '
      '${currentRoute?.hashCode}',
    );

    debugPrint(
      'POP: Current route name = '
      '${currentRoute?.settings.name ?? 'UNKNOWN'}',
    );

    debugPrint('');
    debugPrint('POP: Caller stack trace:');
    debugPrint('${StackTrace.current}');

    debugPrint('');
    debugPrint(
      'POP: Calling navigator.pop<RequestIdVerificationData>(data)...',
    );

    navigator.pop<RequestIdVerificationData>(data);

    debugPrint('');
    debugPrint('POP: navigator.pop(data) COMPLETED.');

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('========== FLOW COMPLETE END =======================');
    debugPrint('====================================================');
  }
}
