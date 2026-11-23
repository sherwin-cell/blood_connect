import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';

/// What is being uploaded; matches the backend's POST /api/files/{kind}.
enum SecureUploadKind {
  idFront('id_front'),
  idBack('id_back'),
  bloodRequestForm('brf');

  const SecureUploadKind(this.path);
  final String path;
}

class SecureUploadException implements Exception {
  const SecureUploadException(this.message, {this.statusCode = 0});

  final String message;

  /// HTTP status, or 0 when the request never reached the server.
  final int statusCode;

  @override
  String toString() => message;
}

/// Uploads ID photos and Blood Request Forms through blood_connect_backend.
///
/// The backend stores them on Cloudinary as private files and returns a
/// `secure://...` reference, which is saved in Firestore in place of a
/// public link. Only the owner and PRC can exchange it for a short-lived
/// viewing link (GET /api/files/view). No Cloudinary preset or key in the app.
class SecureUploadApi {
  SecureUploadApi({
    http.Client? client,
    Future<String?> Function()? idToken,
    String? baseUrl,
    this.timeout = const Duration(seconds: 90),
  }) : _client = client ?? http.Client(),
       _idToken = idToken ?? _currentUserToken,
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final Future<String?> Function() _idToken;
  final String _baseUrl;
  final Duration timeout;

  static Future<String?> _currentUserToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  static MediaType _contentType(String path, SecureUploadKind kind) {
    if (kind == SecureUploadKind.bloodRequestForm) {
      return MediaType('application', 'pdf');
    }
    return path.toLowerCase().endsWith('.png')
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');
  }

  /// Returns the `secure://` reference to store in Firestore.
  Future<String> upload(File file, SecureUploadKind kind) async {
    if (_baseUrl.trim().isEmpty) {
      throw const SecureUploadException(
        'Uploads are not set up in this build '
        '(missing --dart-define=API_BASE_URL).',
      );
    }
    if (!await file.exists() || await file.length() == 0) {
      throw const SecureUploadException(
        'The selected file is empty or missing.',
      );
    }

    final token = await _idToken();
    if (token == null || token.isEmpty) {
      throw const SecureUploadException(
        'Your session expired. Please log in again.',
        statusCode: 401,
      );
    }

    final request =
        http.MultipartRequest(
            'POST',
            ApiConfig.endpoint('/api/files/${kind.path}', base: _baseUrl),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              file.path,
              contentType: _contentType(file.path, kind),
            ),
          );

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const SecureUploadException(
        'The upload took too long. Check your connection and try again.',
      );
    } on SocketException {
      throw const SecureUploadException(
        'Could not reach the Blood-Connect server. Check your connection.',
      );
    } on http.ClientException {
      throw const SecureUploadException(
        'Could not reach the Blood-Connect server. Check your connection.',
      );
    }

    Map<String, dynamic> json = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Non-JSON error page: use the generic message below.
    }

    final ref = json['ref'];
    if (response.statusCode == 200 &&
        ref is String &&
        ref.startsWith('secure://')) {
      return ref;
    }
    throw SecureUploadException(
      (json['message'] as String?) ??
          (json['detail'] is String ? json['detail'] as String : null) ??
          'Upload failed (HTTP ${response.statusCode}). Please try again.',
      statusCode: response.statusCode,
    );
  }
}
