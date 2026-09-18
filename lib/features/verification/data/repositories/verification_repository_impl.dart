import 'dart:io';

import '../../../../core/services/firestore_service.dart';
import '../../domain/entities/face_verification_data.dart';
import '../../domain/entities/request_id_verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';
import '../../domain/services/i_face_embedding_service.dart';
import '../services/cloudinary_service.dart';
import '../services/face_detector_service.dart';

class VerificationRepositoryImpl implements IVerificationRepository {
  final FaceDetectorService faceDetectorService;
  final CloudinaryService cloudinaryService;
  final FirestoreService firestoreService;
  final IFaceEmbeddingService faceEmbeddingService;

  static const double _similarityPassThreshold = 0.75;

  VerificationRepositoryImpl({
    required this.faceDetectorService,
    required this.cloudinaryService,
    required this.firestoreService,
    required this.faceEmbeddingService,
  });

  @override
  Future<bool> detectFace(File imageFile) async {
    return await faceDetectorService.hasValidFace(imageFile);
  }

  @override
  Future<int> countFaces(File imageFile) async {
    return await faceDetectorService.countFaces(imageFile);
  }

  @override
  Future<File?> cropPrimaryFace(File imageFile) async {
    return await faceDetectorService.cropPrimaryFace(imageFile);
  }

  @override
  Future<Map<String, dynamic>> compareFaces({
    required File idCardFace,
    required File selfieFace,
  }) async {
    try {
      final idEmbedding = await faceEmbeddingService.extractEmbedding(
        idCardFace,
      );
      final selfieEmbedding = await faceEmbeddingService.extractEmbedding(
        selfieFace,
      );

      if (idEmbedding == null || selfieEmbedding == null) {
        return {
          'success': false,
          'error': 'Failed to extract face embeddings from one or both images.',
        };
      }

      final double rawSimilarity = faceEmbeddingService.compareEmbeddings(
        idEmbedding,
        selfieEmbedding,
      );

      final bool passed = rawSimilarity >= _similarityPassThreshold;
      final double matchPercentage = (rawSimilarity.clamp(0.0, 1.0)) * 100;

      return {
        'success': true,
        'faceMatchConfidence': matchPercentage,
        'faceMatchPassed': passed,
      };
    } catch (e) {
      return {'success': false, 'error': 'Local face comparison failed: $e'};
    }
  }

  @override
  Future<void> saveFaceVerification({
    required String userId,
    required FaceVerificationData data,
  }) async {
    if (data.selfiePath == null || data.selfiePath!.isEmpty) {
      throw Exception('Selfie image is missing.');
    }

    final selfieUrl = await cloudinaryService.uploadImage(
      File(data.selfiePath!),
    );

    await firestoreService.saveFaceVerification(
      userId: userId,
      selfieCloudinaryUrl: selfieUrl,
      data: data,
    );
  }

  @override
  Future<({String frontUrl, String? backUrl})> uploadRequestIdImages({
    required String frontIdPath,
    String? backIdPath,
  }) async {
    final frontUrl = await cloudinaryService.uploadImage(File(frontIdPath));
    String? backUrl;
    if (backIdPath != null && backIdPath.isNotEmpty) {
      backUrl = await cloudinaryService.uploadImage(File(backIdPath));
    }
    return (frontUrl: frontUrl, backUrl: backUrl);
  }

  @override
  Future<String?> getIdVerificationStatus(String userId) async {
    return await firestoreService.getIdVerificationStatus(userId);
  }

  @override
  Future<String> saveOrUpdateIdSubmission({
    required String userId,
    required RequestIdVerificationData data,
  }) async {
    if (data.frontIdImage == null || data.frontIdImage!.isEmpty) {
      throw Exception('Front ID image is missing.');
    }

    final uploadedUrls = await uploadRequestIdImages(
      frontIdPath: data.frontIdImage!,
      backIdPath: data.backIdImage,
    );

    return await firestoreService.saveIdVerificationSubmission(
      userId: userId,
      frontUrl: uploadedUrls.frontUrl,
      backUrl: uploadedUrls.backUrl,
      data: data,
    );
  }

  @override
  Future<void> offerToDonate({
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorContact,
    required String donorBloodType,
  }) async {
    await firestoreService.offerToDonate(
      requestId: requestId,
      donorId: donorId,
      donorName: donorName,
      donorContact: donorContact,
      donorBloodType: donorBloodType,
    );
  }
}
