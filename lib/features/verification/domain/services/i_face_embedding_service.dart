import 'dart:io';

abstract class IFaceEmbeddingService {
  /// Loads model assets and initializes TFLite interpreter.
  Future<void> initialize();

  /// Extracts face embeddings from a cropped face image file.
  Future<List<double>?> extractEmbedding(File croppedFaceFile);

  /// Calculates cosine similarity between two face embeddings.
  double compareEmbeddings(List<double> embeddingA, List<double> embeddingB);

  /// Releases resources.
  void dispose();
}
