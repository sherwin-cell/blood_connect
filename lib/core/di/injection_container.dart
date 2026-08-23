import 'package:get_it/get_it.dart';

import '../services/firestore_service.dart';
import '../../features/verification/data/repositories/verification_repository_impl.dart';
import '../../features/verification/data/services/cloudinary_service.dart';
import '../../features/verification/data/services/face_detector_service.dart';
import '../../features/verification/domain/services/i_face_embedding_service.dart';
import '../../features/verification/data/services/ocr_service.dart';
import '../../features/verification/data/services/tflite_face_embedding_service.dart';

final sl = GetIt.instance; // sl = Service Locator

Future<void> initServiceLocator() async {
  // 1. External & Core Services
  sl.registerLazySingleton<FirestoreService>(() => FirestoreService());
  sl.registerLazySingleton<OcrService>(() => OcrService());
  sl.registerLazySingleton<FaceDetectorService>(() => FaceDetectorService());
  sl.registerLazySingleton<CloudinaryService>(() => CloudinaryService());

  // 2. Local Face Embedding Service (Lazy Singleton)
  sl.registerLazySingleton<IFaceEmbeddingService>(
    () => TFLiteFaceEmbeddingService(),
  );

  // 3. Verification Repository
  sl.registerLazySingleton<VerificationRepositoryImpl>(
    () => VerificationRepositoryImpl(
      ocrService: sl<OcrService>(),
      faceDetectorService: sl<FaceDetectorService>(),
      faceEmbeddingService: sl<IFaceEmbeddingService>(),
      cloudinaryService: sl<CloudinaryService>(),
      firestoreService: sl<FirestoreService>(),
    ),
  );
}
