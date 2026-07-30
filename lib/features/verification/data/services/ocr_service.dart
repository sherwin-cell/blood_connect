import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<Map<String, String>> extractIdDetails(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );

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
      'rawText': recognizedText.text,
      'idNumber': idNumber,
      'extractedName': extractedName,
    };
  }

  void dispose() {
    _textRecognizer.close();
  }
}
