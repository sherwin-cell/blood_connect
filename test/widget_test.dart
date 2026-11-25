import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_connect/features/auth/data/auth_service.dart';
import 'package:blood_connect/features/blood_request/presentation/screens/post_blood_request_welcome_screen.dart';
import 'package:blood_connect/features/verification/domain/entities/request_id_verification_data.dart';
import 'package:blood_connect/features/verification/presentation/screens/identity_verification_info_screen.dart';

void main() {
  test('AuthService maps user-not-found to a friendly message', () {
    expect(
      AuthService.getErrorMessage(
        FirebaseAuthException(code: 'user-not-found'),
      ),
      'No user found with this email.',
    );
  });

  test('AuthService maps email-already-in-use to a friendly message', () {
    expect(
      AuthService.getErrorMessage(
        FirebaseAuthException(code: 'email-already-in-use'),
      ),
      'This email is already registered. Please log in.',
    );
  });

  test('Approved account statuses bypass ID recapture', () {
    expect(RequestIdVerificationData.isApprovedStatus('approved'), isTrue);
    expect(RequestIdVerificationData.isApprovedStatus('verified'), isTrue);
    expect(RequestIdVerificationData.requiresIdCapture('approved'), isFalse);
    expect(RequestIdVerificationData.requiresIdCapture('verified'), isFalse);
  });

  test(
    'Pending and rejected statuses still require ID review before blood requests',
    () {
      expect(RequestIdVerificationData.requiresIdCapture('pending'), isTrue);
      expect(RequestIdVerificationData.requiresIdCapture('rejected'), isTrue);
      expect(RequestIdVerificationData.requiresIdCapture(null), isTrue);
    },
  );

  testWidgets(
    'Identity verification screen explains the ID-first flow',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: IdentityVerificationInfoScreen()),
      );

      expect(find.text('Identity Verification'), findsAtLeastNWidgets(1));
      expect(
        find.text(
          'Upload a valid ID first, then take a selfie. We match your '
          'face to your ID photo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Upload front and back'), findsOneWidget);
      expect(find.text('Take a selfie'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    },
  );

  testWidgets('Post blood request welcome screen shows steps and checklist', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: PostBloodRequestWelcomeScreen()),
    );

    expect(find.text('Emergency Blood Request'), findsOneWidget);
    expect(find.text('Request Blood in an Emergency'), findsOneWidget);
    expect(find.text('Patient Information'), findsOneWidget);
    expect(find.text('Review & Submit'), findsOneWidget);
    expect(find.text('Blood Request Form (BRF) as a PDF'), findsOneWidget);
    expect(find.byTooltip('Help'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
