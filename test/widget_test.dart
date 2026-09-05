import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blood_connect/features/auth/data/auth_service.dart';

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
}
