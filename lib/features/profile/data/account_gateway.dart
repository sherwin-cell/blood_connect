import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/services/push_notification_service.dart';
import '../../auth/data/auth_service.dart';

enum SignInMethod { password, google, other }

/// Result of DELETE /api/account (blood_connect_backend/account).
class AccountDeletionResult {
  const AccountDeletionResult({
    required this.deleted,
    required this.code,
    required this.message,
  });

  final bool deleted;
  final String code;
  final String message;

  static const requiresRecentLogin = 'requires_recent_login';

  factory AccountDeletionResult.fromResponse(int status, String body) {
    Map<String, dynamic> json = const {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Non-JSON error page.
    }
    final deleted = status == 200 && json['deleted'] == true;
    return AccountDeletionResult(
      deleted: deleted,
      code: json['code'] as String? ?? (deleted ? 'deleted' : 'error_$status'),
      message:
          json['message'] as String? ??
          (deleted
              ? 'Your account has been deleted.'
              : 'We could not delete your account. Please try again later.'),
    );
  }

  factory AccountDeletionResult.failure(String code, String message) =>
      AccountDeletionResult(deleted: false, code: code, message: message);
}

/// Account actions the profile screens need. Behind an interface so the
/// screens can be tested without Firebase or the backend.
abstract class AccountGateway {
  String? get email;
  SignInMethod get signInMethod;

  /// Throws [FirebaseAuthException] when the password is wrong.
  Future<void> reauthenticateWithPassword(String password);

  /// False when the user cancelled the Google account picker.
  Future<bool> reauthenticateWithGoogle();

  /// Deletes the account on the backend (data, images and login).
  Future<AccountDeletionResult> deleteAccount();

  Future<void> sendPasswordReset();

  /// Removes this device's push token, then signs out.
  Future<void> logOut();

  /// Local sign-out after the backend deleted the account.
  Future<void> signOutAfterDeletion();
}

class FirebaseAccountGateway implements AccountGateway {
  FirebaseAccountGateway({
    FirebaseAuth? auth,
    AuthService? authService,
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 60),
  }) : _authOverride = auth,
       _authService = authService ?? AuthService(),
       _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final FirebaseAuth? _authOverride;
  final AuthService _authService;
  final http.Client _client;
  final String _baseUrl;
  final Duration timeout;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  SignInMethod get signInMethod {
    final providers =
        _auth.currentUser?.providerData.map((p) => p.providerId).toSet() ??
        const <String>{};
    if (providers.contains('password')) return SignInMethod.password;
    if (providers.contains('google.com')) return SignInMethod.google;
    return SignInMethod.other;
  }

  @override
  Future<void> reauthenticateWithPassword(String password) =>
      _authService.reauthenticateWithPassword(password);

  @override
  Future<bool> reauthenticateWithGoogle() =>
      _authService.reauthenticateWithGoogle();

  @override
  Future<AccountDeletionResult> deleteAccount() async {
    if (_baseUrl.trim().isEmpty) {
      return AccountDeletionResult.failure(
        'app_not_configured',
        'Account deletion is not set up in this build '
            '(missing --dart-define=API_BASE_URL).',
      );
    }
    final user = _auth.currentUser;
    if (user == null) {
      return AccountDeletionResult.failure(
        'unauthenticated',
        'Your session expired. Please log in again.',
      );
    }
    try {
      // Force a new token so it carries the fresh sign-in time.
      final token = await user.getIdToken(true);
      final response = await _client
          .delete(
            ApiConfig.endpoint('/api/account', base: _baseUrl),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(timeout);
      return AccountDeletionResult.fromResponse(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return AccountDeletionResult.failure(
        'network',
        'The server took too long to respond. Your account was not deleted.',
      );
    } on SocketException {
      return AccountDeletionResult.failure(
        'network',
        'Could not reach the server. Check your connection and try again.',
      );
    } on http.ClientException {
      return AccountDeletionResult.failure(
        'network',
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> sendPasswordReset() async {
    final address = email;
    if (address == null) return;
    await _authService.sendPasswordResetEmail(address);
  }

  @override
  Future<void> logOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await PushNotificationService.instance.unregisterCurrentDevice(uid);
    }
    await _authService.logout();
  }

  @override
  Future<void> signOutAfterDeletion() async {
    await PushNotificationService.instance.clearRegisteredUser();
    try {
      await _authService.logout();
    } catch (_) {
      // The Auth user no longer exists; the local session is cleared anyway.
      await _auth.signOut();
    }
  }
}
