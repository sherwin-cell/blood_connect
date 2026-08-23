import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/services/firestore_service.dart';
import '../../domain/entities/verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';
import '../../domain/services/i_face_embedding_service.dart';
import '../services/cloudinary_service.dart';
import '../services/face_detector_service.dart';
import '../services/ocr_service.dart';

class VerificationRepositoryImpl implements IVerificationRepository {
  final OcrService ocrService;
  final FaceDetectorService faceDetectorService;
  final CloudinaryService cloudinaryService;
  final FirestoreService firestoreService;
  final IFaceEmbeddingService faceEmbeddingService;

  /// Recommended pass threshold for MobileFaceNet cosine similarity (75%)
  static const double _similarityPassThreshold = 0.75;

  VerificationRepositoryImpl({
    required this.ocrService,
    required this.faceDetectorService,
    required this.cloudinaryService,
    required this.firestoreService,
    required this.faceEmbeddingService,
  });

  @override
  Future<Map<String, String?>> processIdOcr(File imageFile) async {
    return await ocrService.extractIdDetails(imageFile);
  }

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

  /// Compares two cropped face images locally using the embedded TFLite model
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

      // Cosine similarity returns a value between -1.0 and 1.0 (typically 0.0 to 1.0 for faces)
      final double rawSimilarity = faceEmbeddingService.compareEmbeddings(
        idEmbedding,
        selfieEmbedding,
      );

      // Evaluate against the 0.75 (75%) threshold
      final bool passed = rawSimilarity >= _similarityPassThreshold;

      // Convert raw similarity (0.0 - 1.0) to percentage scale (0.0 - 100.0)
      final double matchPercentage = (rawSimilarity.clamp(0.0, 1.0)) * 100;

      debugPrint('========================================');
      debugPrint('=== LOCAL FACE MATCH RESULT ===');
      debugPrint('Raw Cosine Similarity: ${rawSimilarity.toStringAsFixed(4)}');
      debugPrint('Match Percentage: ${matchPercentage.toStringAsFixed(1)}%');
      debugPrint('Passed Threshold (>= 75%): $passed');
      debugPrint('========================================');

      return {
        'success': true,
        'faceMatchConfidence':
            matchPercentage, // Storing as percentage e.g. 82.5
        'faceMatchPassed': passed,
      };
    } catch (e) {
      return {'success': false, 'error': 'Local face comparison failed: $e'};
    }
  }

  @override
  Future<void> submitVerification({
    required String userId,
    required VerificationData data,
    required String status,
  }) async {
    debugPrint('========================================');
    debugPrint('=== CLOUDINARY UPLOAD ===');

    try {
      // 1. Upload Front ID Image to Cloudinary
      final idUrl = await cloudinaryService.uploadImage(
        File(data.idImagePath!),
      );
      debugPrint('ID URL: $idUrl');

      // 2. Upload Back ID Image if available
      String? backIdUrl;
      if (data.backIdImagePath != null && data.backIdImagePath!.isNotEmpty) {
        backIdUrl = await cloudinaryService.uploadImage(
          File(data.backIdImagePath!),
        );
        debugPrint('Back ID URL: $backIdUrl');
      }

      // 3. Upload Selfie Image to Cloudinary
      final selfieUrl = await cloudinaryService.uploadImage(
        File(data.selfiePath!),
      );
      debugPrint('Selfie URL: $selfieUrl');
      debugPrint('========================================');

      debugPrint('========================================');
      debugPrint('=== FIRESTORE SAVE ===');
      debugPrint('userId: $userId');
      debugPrint('status: $status');
      debugPrint('faceMatchConfidence: ${data.faceMatchConfidence}%');
      debugPrint('faceMatchPassed: ${data.faceMatchPassed}');
      debugPrint('verificationProvider: ${data.verificationProvider}');

      // 4. Save URLs, score, status, & extracted details to Firestore
      await firestoreService.submitVerificationRecord(
        userId: userId,
        data: data,
        status: status,
        idCloudinaryUrl: idUrl,
        backIdCloudinaryUrl: backIdUrl,
        selfieCloudinaryUrl: selfieUrl,
        faceMatchConfidence: data.faceMatchConfidence,
        faceMatchPassed: data.faceMatchPassed,
      );
      debugPrint('Firestore save completed.');
      debugPrint('========================================');
    } catch (e, stackTrace) {
      debugPrint('Cloudinary/Firestore failure: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }
}
