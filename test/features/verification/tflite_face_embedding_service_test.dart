import 'package:flutter_test/flutter_test.dart';
import 'package:blood_connect/features/verification/data/services/tflite_face_embedding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TFLiteFaceEmbeddingService service;

  setUp(() {
    service = TFLiteFaceEmbeddingService();
  });

  tearDown(() {
    service.dispose();
  });

  test(
    'TFLiteFaceEmbeddingService calculates high similarity for identical embeddings',
    () {
      final listA = List<double>.generate(192, (i) => (i + 1).toDouble());
      final listB = List<double>.generate(192, (i) => (i + 1).toDouble());

      final similarity = service.compareEmbeddings(listA, listB);

      // Identical non-zero vectors yield cosine similarity of exactly 1.0
      expect(similarity, closeTo(1.0, 0.0001));
    },
  );

  test(
    'TFLiteFaceEmbeddingService calculates low similarity for orthogonal/opposite embeddings',
    () {
      final listA = List<double>.filled(192, 1.0);
      final listB = List<double>.filled(192, -1.0);

      final similarity = service.compareEmbeddings(listA, listB);

      // Directly opposite vectors yield cosine similarity of -1.0
      expect(similarity, lessThan(0.5));
    },
  );
}
