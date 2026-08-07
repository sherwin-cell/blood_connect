import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Thrown when the captured photo doesn't contain enough readable text
/// to plausibly be a government ID (e.g. blank background, blurry shot,
/// or no card in frame at all).
class NoIdDetectedException implements Exception {
  final String message;
  NoIdDetectedException([this.message = 'No valid ID detected in the photo.']);

  @override
  String toString() => message;
}

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Minimum characters of recognized text required to consider the photo
  /// a plausible ID capture.
  static const int _minTextLengthThreshold = 25;

  Future<Map<String, String?>> extractIdDetails(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );

    debugPrint('RAW OCR TEXT:\n${recognizedText.text}');

    final String rawText = recognizedText.text.trim();

    // Guard: reject photos that clearly don't contain a real ID.
    if (rawText.length < _minTextLengthThreshold) {
      throw NoIdDetectedException(
        'We couldn\'t read any ID details from that photo. '
        'Please make sure your government ID is clearly visible, '
        'well-lit, and fills the frame, then try again.',
      );
    }

    String? extractedName;
    String? idNumber;
    String? extractedBirthDate;
    String? extractedGender;

    final List<String> lines = [];
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        lines.add(line.text.trim());
      }
    }

    // 1. DATE OF BIRTH EXTRACTION
    // Matches formats: YYYY/MM/DD, YYYY-MM-DD, DD/MM/YYYY, DD MMM YYYY (e.g., 11 JUL 1995)
    final dobRegex = RegExp(
      r'\b(19|20)\d{2}[-/.]\d{2}[-/.]\d{2}\b|\b\d{2}[-/.]\d{2}[-/.] (19|20)\d{2}\b|\b\d{1,2}\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[a-z]*\s+(19|20)\d{2}\b',
      caseSensitive: false,
    );

    for (String line in lines) {
      // Avoid matching Expiration Date or Issue Date labels if on same line
      if (line.toLowerCase().contains('exp') ||
          line.toLowerCase().contains('issue')) {
        continue;
      }

      final match = dobRegex.firstMatch(line);
      if (match != null && extractedBirthDate == null) {
        extractedBirthDate = match.group(0);
        break;
      }
    }

    // 2. ID NUMBER EXTRACTION
    // Matches patterns like N01-12-345678, 1234-5678-9012, or standalone digit blocks
    final idNumRegex = RegExp(
      r'\b[A-Z0-9]{3}[-\s]?\d{2}[-\s]?\d{6}\b|\b\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',
    );

    for (String line in lines) {
      final match = idNumRegex.firstMatch(line);
      if (match != null) {
        idNumber = match.group(0);
        break;
      }
    }

    // 3. GENDER EXTRACTION
    for (String line in lines) {
      final l = line.toUpperCase();
      if (l == 'M' || l.contains('MALE') || l.contains('SEX: M')) {
        extractedGender = 'Male';
        break;
      } else if (l == 'F' || l.contains('FEMALE') || l.contains('SEX: F')) {
        extractedGender = 'Female';
        break;
      }
    }

    // 4. NAME EXTRACTION HEURISTIC
    // Look for comma-separated names (e.g. "ESCANILLA, SHERWIN RANGEL")
    final nameRegex = RegExp(r'^[A-Z\s]+,\s*[A-Z\s]+$');
    for (String line in lines) {
      if (nameRegex.hasMatch(line) && !line.contains('REPUBLIC')) {
        extractedName = line;
        break;
      }
    }

    return {
      'rawText': rawText,
      'idNumber': idNumber ?? '',
      'extractedName': extractedName ?? '',
      'extractedBirthDate': extractedBirthDate ?? '',
      'extractedGender': extractedGender ?? '',
    };
  }

  void dispose() {
    _textRecognizer.close();
  }
}
