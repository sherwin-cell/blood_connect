import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/services/firestore_service.dart';
import '../../domain/entities/verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';
import '../services/cloudinary_service.dart';
import '../services/face_detector_service.dart';
import '../services/ocr_service.dart';

class VerificationRepositoryImpl implements IVerificationRepository {
  final OcrService ocrService;
  final FaceDetectorService faceDetectorService;
  final CloudinaryService cloudinaryService;
  final FirestoreService firestoreService;

  VerificationRepositoryImpl({
    required this.ocrService,
    required this.faceDetectorService,
    required this.cloudinaryService,
    required this.firestoreService,
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

  @override
  Future<void> submitVerification({
    required String userId,
    required VerificationData data,
  }) async {
    debugPrint('========================================');
    debugPrint('=== CLOUDINARY UPLOAD ===');

    try {
      // 1. Upload Front ID Image to Cloudinary
      final idUrl = await cloudinaryService.uploadImage(File(data.idImagePath!));
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
      debugPrint('faceMatchConfidence: ${data.faceMatchConfidence}');
      debugPrint('faceMatchPassed: ${data.faceMatchPassed}');
      debugPrint('verificationProvider: ${data.verificationProvider}');

      // 4. Save URLs, ARSA score, & extracted details to Firestore
      await firestoreService.submitVerificationRecord(
        userId: userId,
        data: data,
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
