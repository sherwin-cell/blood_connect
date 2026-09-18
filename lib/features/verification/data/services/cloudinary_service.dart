import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dlk8chosr';
  static const String uploadPreset = 'blood_connect_upload';

  Future<String> uploadImage(File imageFile) async {
    // Validate file
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist.');
    }

    final fileLength = await imageFile.length();

    if (fileLength == 0) {
      throw Exception('Image file is empty.');
    }

    debugPrint('========== CLOUDINARY UPLOAD ==========');
    debugPrint('File: ${imageFile.path}');
    debugPrint('File size: $fileLength bytes');

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    try {
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      debugPrint('Sending image to Cloudinary...');

      final response = await request.send();

      final responseBody = await response.stream.bytesToString();

      debugPrint('Cloudinary HTTP Status: ${response.statusCode}');
      debugPrint('Cloudinary Response: $responseBody');

      // Successful upload
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(responseBody);

        if (decoded is! Map<String, dynamic>) {
          throw Exception('Cloudinary returned an invalid response.');
        }

        final secureUrl = decoded['secure_url'];

        if (secureUrl == null || secureUrl.toString().isEmpty) {
          throw Exception(
            'Cloudinary upload succeeded but no secure_url was returned.',
          );
        }

        debugPrint('Cloudinary upload successful.');
        debugPrint('Secure URL: $secureUrl');
        debugPrint('======================================');

        return secureUrl.toString();
      }

      // Cloudinary returned an error
      String errorMessage = 'Unknown Cloudinary error.';

      try {
        final dynamic decoded = jsonDecode(responseBody);

        if (decoded is Map<String, dynamic>) {
          final error = decoded['error'];

          if (error is Map<String, dynamic>) {
            errorMessage = error['message']?.toString() ?? errorMessage;
          }
        }
      } catch (_) {
        // Keep the original response if it is not valid JSON.
      }

      debugPrint('Cloudinary upload FAILED.');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Error: $errorMessage');
      debugPrint('======================================');

      throw Exception(
        'Cloudinary upload failed '
        '(HTTP ${response.statusCode}): $errorMessage',
      );
    } catch (e, stackTrace) {
      debugPrint('========== CLOUDINARY ERROR ==========');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('======================================');

      rethrow;
    }
  }
}
