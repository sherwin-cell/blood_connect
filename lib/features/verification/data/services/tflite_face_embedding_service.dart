import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Import services for rootBundle
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../domain/services/i_face_embedding_service.dart';

class TFLiteFaceEmbeddingService implements IFaceEmbeddingService {
  Interpreter? _interpreter;

  @override
  Future<void> initialize() async {
    if (_interpreter != null) return;
    try {
      // Load raw byte data directly from rootBundle
      final ByteData rawAsset = await rootBundle.load(
        'assets/models/mobile_facenet.tflite',
      );
      final Uint8List bytes = rawAsset.buffer.asUint8List(
        rawAsset.offsetInBytes,
        rawAsset.lengthInBytes,
      );

      _interpreter = Interpreter.fromBuffer(bytes);
      debugPrint('TFLite model successfully initialized from buffer.');
    } catch (e) {
      debugPrint('Error loading TFLite model: $e');
      rethrow;
    }
  }

  @override
  Future<List<double>?> extractEmbedding(File croppedFaceFile) async {
    if (_interpreter == null) {
      await initialize();
    }

    try {
      final bytes = await croppedFaceFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final resized = img.copyResize(image, width: 112, height: 112);

      var input = List.generate(
        1,
        (_) => List.generate(
          112,
          (y) => List.generate(112, (x) {
            final pixel = resized.getPixel(x, y);
            return [
              (pixel.r - 127.5) / 127.5,
              (pixel.g - 127.5) / 127.5,
              (pixel.b - 127.5) / 127.5,
            ];
          }),
        ),
      );

      var output = List.filled(1 * 192, 0.0).reshape([1, 192]);

      _interpreter!.run(input, output);

      List<double> embedding = List<double>.from(output[0]);
      return embedding;
    } catch (e) {
      debugPrint('Error extracting embedding: $e');
      return null;
    }
  }

  @override
  double compareEmbeddings(List<double> embeddingA, List<double> embeddingB) {
    if (embeddingA.length != embeddingB.length || embeddingA.isEmpty) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double sumSqA = 0.0;
    double sumSqB = 0.0;

    for (int i = 0; i < embeddingA.length; i++) {
      dotProduct += embeddingA[i] * embeddingB[i];
      sumSqA += embeddingA[i] * embeddingA[i];
      sumSqB += embeddingB[i] * embeddingB[i];
    }

    double normA = sqrt(sumSqA);
    double normB = sqrt(sumSqB);

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dotProduct / (normA * normB);
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
