import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';

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
  /// a plausible ID capture. A blank wall or random object typically
  /// yields little to no text; a real ID card has a name, ID number,
  /// dates, and various labels — comfortably above this threshold.
  static const int _minTextLengthThreshold = 25;

  Future<Map<String, String>> extractIdDetails(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );

    debugPrint(
      'RAW OCR TEXT:\n${recognizedText.text}',
    ); // ← add this line temporarily

    final String rawText = recognizedText.text.trim();

    // Guard: reject photos that clearly don't contain a real ID.
    if (rawText.length < _minTextLengthThreshold) {
      throw NoIdDetectedException(
        'We couldn\'t read any ID details from that photo. '
        'Please make sure your government ID is clearly visible, '
        'well-lit, and fills the frame, then try again.',
      );
    }

    String extractedName = '';
    String idNumber = '';

    // Simple line-by-line parsing strategy
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final text = line.text.trim();
        // Look for common ID number patterns (digits with hyphens)
        if (RegExp(r'^\d{4}[-\s]?\d{4}[-\s]?\d{4}$').hasMatch(text)) {
          idNumber = text;
        }
        // Fallback or full text capture for admin review
      }
    }

    return {
      'rawText': rawText,
      'idNumber': idNumber,
      'extractedName': extractedName,
    };
  }

  void dispose() {
    _textRecognizer.close();
  }
}
