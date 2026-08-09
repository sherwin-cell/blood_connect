import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

/// Calls ARSA Face Recognition `validate_faces` (1:1 comparison).
///
/// DEV ONLY: the API key is injected via the constructor for local testing.
/// Production builds should call ARSA through a secure backend / Cloud Function
/// so the key is never embedded in the APK.
class ArsaFaceService {
  static const String _baseUrl = 'https://faceapi.arsa.technology';

  final String _apiKey;

  ArsaFaceService(this._apiKey);

  Future<Map<String, dynamic>> compareFaces({
    required File idImage,
    required File selfieImage,
  }) async {
    debugPrint('========================================');
    debugPrint('=== ARSA INPUT ===');
    debugPrint('ID path: ${idImage.path}');
    debugPrint('Selfie path: ${selfieImage.path}');

    try {
      final idExists = await idImage.exists();
      final selfieExists = await selfieImage.exists();

      debugPrint('ID exists: $idExists');
      debugPrint('Selfie exists: $selfieExists');

      if (!idExists) {
        return {
          'success': false,
          'errorCode': 'missing_id',
          'error': 'Government ID image is missing.',
        };
      }

      if (!selfieExists) {
        return {
          'success': false,
          'errorCode': 'missing_selfie',
          'error': 'Selfie image is missing.',
        };
      }

      final idSize = await idImage.length();
      final selfieSize = await selfieImage.length();
      final idExt = p.extension(idImage.path).toLowerCase();
      final selfieExt = p.extension(selfieImage.path).toLowerCase();

      debugPrint('ID size: $idSize');
      debugPrint('Selfie size: $selfieSize');
      debugPrint('ID extension: $idExt');
      debugPrint('Selfie extension: $selfieExt');
      debugPrint('========================================');

      if (idSize == 0) {
        return {
          'success': false,
          'errorCode': 'empty_id',
          'error': 'Government ID image is empty.',
        };
      }

      if (selfieSize == 0) {
        return {
          'success': false,
          'errorCode': 'empty_selfie',
          'error': 'Selfie image is empty.',
        };
      }

      if (!_isSupportedImageExtension(idExt)) {
        return {
          'success': false,
          'errorCode': 'invalid_image',
          'error':
              'Government ID must be a JPEG or PNG image. Got "$idExt".',
        };
      }

      if (!_isSupportedImageExtension(selfieExt)) {
        return {
          'success': false,
          'errorCode': 'invalid_image',
          'error': 'Selfie must be a JPEG or PNG image. Got "$selfieExt".',
        };
      }
    } catch (e, stackTrace) {
      debugPrint('File validation error: $e');
      debugPrint('$stackTrace');
      return {
        'success': false,
        'errorCode': 'invalid_image',
        'error': 'Unable to validate image files: $e',
      };
    }

    final url = Uri.parse('$_baseUrl/api/v1/face_recognition/validate_faces');

    final selfieContentType = _mediaTypeForPath(selfieImage.path);
    final idContentType = _mediaTypeForPath(idImage.path);

    debugPrint('========================================');
    debugPrint('=== ARSA REQUEST ===');
    debugPrint('URL: $url');
    debugPrint('Method: POST');
    debugPrint('Content-Type: multipart/form-data (auto boundary)');
    debugPrint(
      'Multipart field 1: image1 = selfie '
      '(${p.basename(selfieImage.path)}, $selfieContentType)',
    );
    debugPrint(
      'Multipart field 2: image2 = government ID '
      '(${p.basename(idImage.path)}, $idContentType)',
    );
    debugPrint('API key configured: ${_apiKey.isNotEmpty}');
    debugPrint('========================================');

    final request = http.MultipartRequest('POST', url);

    // Documented auth header: x-key-secret
    request.headers['x-key-secret'] = _apiKey;

    // Documented fields: image1 = selfie, image2 = ID photo
    request.files.add(
      await http.MultipartFile.fromPath(
        'image1',
        selfieImage.path,
        filename: _safeFilename(selfieImage.path, fallback: 'selfie.jpg'),
        contentType: selfieContentType,
      ),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'image2',
        idImage.path,
        filename: _safeFilename(idImage.path, fallback: 'id.jpg'),
        contentType: idContentType,
      ),
    );

    try {
      final streamedResponse = await request
          .send()
          .timeout(const Duration(seconds: 45));
      final statusCode = streamedResponse.statusCode;
      final responseBody = await streamedResponse.stream.bytesToString();

      debugPrint('========================================');
      debugPrint('=== ARSA RESPONSE ===');
      debugPrint('Status Code: $statusCode');
      debugPrint('Response Body: $responseBody');

      Map<String, dynamic>? json;
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
          debugPrint('Decoded JSON: $json');
        } else {
          debugPrint('Decoded JSON (non-map): $decoded');
        }
      } catch (e) {
        debugPrint('Response is not valid JSON: $e');
      }
      debugPrint('========================================');

      if (statusCode == 401 || statusCode == 403) {
        return {
          'success': false,
          'httpStatus': statusCode,
          'responseBody': responseBody,
          'raw': json,
          'errorCode': 'auth',
          'error': 'ARSA authentication failed (HTTP $statusCode).',
        };
      }

      if (statusCode == 404) {
        return {
          'success': false,
          'httpStatus': statusCode,
          'responseBody': responseBody,
          'raw': json,
          'errorCode': 'not_found',
          'error': 'ARSA endpoint not found (HTTP 404).',
        };
      }

      if (statusCode == 429) {
        return {
          'success': false,
          'httpStatus': statusCode,
          'responseBody': responseBody,
          'raw': json,
          'errorCode': 'rate_limit',
          'error': 'ARSA rate limit exceeded. Please try again later.',
        };
      }

      if (statusCode >= 500) {
        return {
          'success': false,
          'httpStatus': statusCode,
          'responseBody': responseBody,
          'raw': json,
          'errorCode': 'server',
          'error': 'ARSA server error (HTTP $statusCode).',
        };
      }

      if (statusCode == 400 || statusCode == 422) {
        final message = _extractErrorMessage(json, responseBody);
        final errorCode = _mapFaceValidationError(message);
        return {
          'success': false,
          'httpStatus': statusCode,
          'responseBody': responseBody,
          'raw': json,
          'errorCode': errorCode,
          'error': message,
        };
      }

      if (statusCode < 200 || statusCode >= 300) {
        return {
          'success': false,
          'httpStatus': statusCode,
          'responseBody': responseBody,
          'raw': json,
          'errorCode': 'http_error',
          'error': 'ARSA returned HTTP status $statusCode.',
        };
      }

      if (json == null) {
        return {
          'success': false,
          'httpStatus': statusCode,
          'responseBody': responseBody,
          'errorCode': 'invalid_json',
          'error': 'ARSA returned an invalid JSON response.',
        };
      }

      // Documented success fields from ARSA docs / live responses:
      // status, match_result, similarity_score (0.0–1.0)
      final arsaStatus = json['status'];
      if (arsaStatus == 'fail' || arsaStatus == 'error') {
        final message = _extractErrorMessage(json, responseBody);
        return {
          'success': false,
          'httpStatus': statusCode,
          'responseBody': responseBody,
          'raw': json,
          'errorCode': _mapFaceValidationError(message),
          'error': message,
        };
      }

      final matchResult = json['match_result'] == true;
      final similarity = _parseSimilarity(json['similarity_score']);

      // ARSA documents similarity_score as 0.0–1.0. Convert to 0–100 only when
      // the value is clearly in the unit interval (do not multiply if already %).
      final faceMatchScore = similarity == null
          ? null
          : (similarity <= 1.0 ? similarity * 100.0 : similarity);

      debugPrint('ARSA status: $arsaStatus');
      debugPrint('ARSA match_result: $matchResult');
      debugPrint('ARSA similarity_score (raw 0–1): $similarity');
      debugPrint(
        'ARSA faceMatchScore (0–100): '
        '${faceMatchScore?.toStringAsFixed(2)}',
      );

      return {
        'success': true,
        'httpStatus': statusCode,
        'faceMatchScore': faceMatchScore,
        'faceMatchPassed': matchResult,
        'similarityScore': similarity,
        'matchResult': matchResult,
        'status': arsaStatus,
        'raw': json,
        'responseBody': responseBody,
      };
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('=== ARSA TIMEOUT ===');
      debugPrint('Error: $e');
      debugPrint('$stackTrace');
      return {
        'success': false,
        'errorCode': 'timeout',
        'error': 'ARSA request timed out. Please try again.',
      };
    } on http.ClientException catch (e, stackTrace) {
      debugPrint('=== ARSA NETWORK ERROR ===');
      debugPrint('Error: $e');
      debugPrint('$stackTrace');
      return {
        'success': false,
        'errorCode': 'network',
        'error': 'Network error while contacting ARSA: $e',
      };
    } on SocketException catch (e, stackTrace) {
      debugPrint('=== ARSA NETWORK ERROR ===');
      debugPrint('Error: $e');
      debugPrint('$stackTrace');
      return {
        'success': false,
        'errorCode': 'network',
        'error': 'Network error while contacting ARSA: $e',
      };
    } catch (e, stackTrace) {
      debugPrint('=== ARSA HTTP ERROR ===');
      debugPrint('Error: $e');
      debugPrint('$stackTrace');
      return {
        'success': false,
        'errorCode': 'network',
        'error': 'HTTP request failed: $e',
      };
    }
  }

  static bool _isSupportedImageExtension(String ext) {
    return ext == '.jpg' ||
        ext == '.jpeg' ||
        ext == '.png' ||
        // Camera plugin sometimes returns paths without an extension on some
        // devices; treat empty as JPEG after magic-byte checks are skipped.
        ext.isEmpty;
  }

  static MediaType _mediaTypeForPath(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.png') {
      return MediaType('image', 'png');
    }
    return MediaType('image', 'jpeg');
  }

  static String _safeFilename(String filePath, {required String fallback}) {
    final name = p.basename(filePath);
    if (name.isEmpty || !name.contains('.')) {
      return fallback;
    }
    return name;
  }

  static double? _parseSimilarity(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String _extractErrorMessage(
    Map<String, dynamic>? json,
    String responseBody,
  ) {
    if (json == null) {
      return responseBody.isEmpty
          ? 'ARSA returned an empty error response.'
          : responseBody;
    }

    final message = json['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }

    final detail = json['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      return detail.toString();
    }

    return responseBody.isEmpty ? 'ARSA request failed.' : responseBody;
  }

  static String _mapFaceValidationError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('multiple faces')) {
      return 'multiple_faces';
    }
    if (lower.contains('could not detect faces') ||
        lower.contains('no face') ||
        lower.contains('face not detected')) {
      return 'no_face';
    }
    return 'arsa_400';
  }
}
