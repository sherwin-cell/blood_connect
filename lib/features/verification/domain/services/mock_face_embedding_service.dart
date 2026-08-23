import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/services/i_face_embedding_service.dart';

class MockFaceEmbeddingService implements IFaceEmbeddingService {
  @override
  Future<void> initialize() async {
    debugPrint('MockFaceEmbeddingService initialized.');
  }

  @override
  Future<List<double>?> extractEmbedding(File croppedFaceFile) async {
    // Generate a mock 128-d embedding vector for testing
    final random = Random();
    return List<double>.generate(128, (_) => random.nextDouble());
  }

  @override
  double compareEmbeddings(List<double> embeddingA, List<double> embeddingB) {
    // Return a mock passing confidence percentage (0-100%)
    return 88.5;
  }

  @override
  void dispose() {
    debugPrint('MockFaceEmbeddingService disposed.');
  }
}
