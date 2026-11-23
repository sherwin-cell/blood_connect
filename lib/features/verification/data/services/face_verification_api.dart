import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../core/config/api_config.dart';

/// What the backend decided about a selfie. Mirrors the JSON returned by
/// POST /api/verification/face in blood_connect_backend.
class FaceVerificationOutcome {
  const FaceVerificationOutcome({
    required this.statusCode,
    required this.code,
    required this.message,
    this.passed = false,
    this.alreadyVerified = false,
    this.score,
    this.attemptsRemaining,
    this.savedForReview = false,
  });

  /// HTTP status, or 0 when the request never reached the server.
  final int statusCode;
  final String code;
  final String message;
  final bool passed;
  final bool alreadyVerified;
  final double? score;
  final int? attemptsRemaining;

  /// The backend kept this selfie so PRC can compare it with the ID.
  final bool savedForReview;

  /// Daily attempt limit used up (HTTP 429).
  bool get limitReached =>
      statusCode == 429 || code == FaceVerificationCode.attemptLimit;

  /// The server (or the connection to it) failed, not the user's photo.
  /// None of these spend a daily attempt.
  bool get isServerProblem =>
      statusCode == 0 ||
      statusCode >= 500 ||
      const {
        FaceVerificationCode.notConfigured,
        FaceVerificationCode.network,
        FaceVerificationCode.serverError,
        'not_configured',
        'matcher_unavailable',
        'id_image_unavailable',
        'upload_failed',
      }.contains(code);

  /// No ID on file yet; the user must upload their ID first.
  bool get idRequired => code == FaceVerificationCode.idRequired;

  /// The user can take another selfie today.
  bool get canRetry =>
      !passed &&
      !limitReached &&
      !idRequired &&
      code != FaceVerificationCode.noFaceInId &&
      code != FaceVerificationCode.invalidIdImageUrl &&
      (attemptsRemaining == null || attemptsRemaining! > 0);

  factory FaceVerificationOutcome.fromResponse(int statusCode, String body) {
    Map<String, dynamic> json = const {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Non-JSON error page (proxy, crash): fall through to generic text.
    }

    final code =
        (json['code'] as String?) ??
        (statusCode == 429
            ? FaceVerificationCode.attemptLimit
            : statusCode == 401
            ? FaceVerificationCode.unauthenticated
            : FaceVerificationCode.serverError);

    return FaceVerificationOutcome(
      statusCode: statusCode,
      code: code,
      message:
          (json['message'] as String?) ??
          (json['detail'] is String ? json['detail'] as String : null) ??
          _fallbackMessage(code),
      passed: json['passed'] == true && statusCode == 200,
      alreadyVerified: json['alreadyVerified'] == true,
      score: (json['score'] as num?)?.toDouble(),
      attemptsRemaining: (json['attemptsRemaining'] as num?)?.toInt(),
      savedForReview: json['savedForReview'] == true,
    );
  }

  factory FaceVerificationOutcome.local(String code, String message) =>
      FaceVerificationOutcome(statusCode: 0, code: code, message: message);

  static String _fallbackMessage(String code) {
    switch (code) {
      case FaceVerificationCode.attemptLimit:
        return 'You have used all face verification attempts for today. '
            'Try again tomorrow, or wait for PRC to review your account.';
      case FaceVerificationCode.unauthenticated:
        return 'Your session expired. Please log in again.';
      default:
        return 'Face verification is not available right now. '
            'Please try again later.';
    }
  }
}

/// `code` values from the backend, plus a few the app adds itself.
abstract final class FaceVerificationCode {
  static const verified = 'verified';
  static const notMatched = 'not_matched';
  static const alreadyVerified = 'already_verified';
  static const idRequired = 'id_required';
  static const invalidIdImageUrl = 'invalid_id_image_url';
  static const attemptLimit = 'attempt_limit';
  static const noFaceInSelfie = 'no_face_in_selfie';
  static const noFaceInId = 'no_face_in_id';

  // App-side only.
  static const notConfigured = 'app_not_configured';
  static const network = 'network';
  static const unauthenticated = 'unauthenticated';
  static const serverError = 'server_error';
}

/// Sends the selfie to the backend, which compares it with the user's saved
/// ID photo and records the result. No matching logic or keys in the app.
class FaceVerificationApi {
  FaceVerificationApi({
    http.Client? client,
    Future<String?> Function()? idToken,
    String? baseUrl,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client(),
       _idToken = idToken ?? _currentUserToken,
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final Future<String?> Function() _idToken;
  final String _baseUrl;
  final Duration timeout;

  static const path = '/api/verification/face';

  static Future<String?> _currentUserToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  Future<FaceVerificationOutcome> verifySelfie(File selfie) async {
    if (_baseUrl.trim().isEmpty) {
      return FaceVerificationOutcome.local(
        FaceVerificationCode.notConfigured,
        'Face verification is not set up in this build '
        '(missing --dart-define=API_BASE_URL).',
      );
    }

    final token = await _idToken();
    if (token == null || token.isEmpty) {
      return FaceVerificationOutcome.local(
        FaceVerificationCode.unauthenticated,
        'Your session expired. Please log in again.',
      );
    }

    final lower = selfie.path.toLowerCase();
    final request =
        http.MultipartRequest('POST', ApiConfig.endpoint(path, base: _baseUrl))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            await http.MultipartFile.fromPath(
              'selfie',
              selfie.path,
              contentType: lower.endsWith('.png')
                  ? MediaType('image', 'png')
                  : MediaType('image', 'jpeg'),
            ),
          );

    try {
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      return FaceVerificationOutcome.fromResponse(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return FaceVerificationOutcome.local(
        FaceVerificationCode.network,
        'The verification server took too long to respond. Please try again.',
      );
    } on SocketException {
      return FaceVerificationOutcome.local(
        FaceVerificationCode.network,
        'Could not reach the verification server. Check your connection.',
      );
    } on http.ClientException {
      return FaceVerificationOutcome.local(
        FaceVerificationCode.network,
        'Could not reach the verification server. Check your connection.',
      );
    }
  }
}
