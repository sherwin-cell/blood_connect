import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_connect/features/auth/data/auth_service.dart';
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
}
