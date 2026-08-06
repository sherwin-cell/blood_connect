import 'dart:io';
import '../../domain/entities/verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';
import '../services/ocr_service.dart';
import '../services/face_detector_service.dart';
import '../services/cloudinary_service.dart';
import '../../../../core/services/firestore_service.dart';

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
  Future<Map<String, String>> processIdOcr(File imageFile) async {
    return await ocrService.extractIdDetails(imageFile);
  }

  @override
  Future<bool> detectFace(File imageFile) async {
    return await faceDetectorService.hasValidFace(imageFile);
  }

  @override
  Future<void> submitVerification({
    required String userId,
    required VerificationData data,
  }) async {
    // 1. Upload Front ID Image to Cloudinary
    final idUrl = await cloudinaryService.uploadImage(File(data.idImagePath!));

    // 2. Upload Back ID Image if available
    String? backIdUrl;
    if (data.backIdImagePath != null && data.backIdImagePath!.isNotEmpty) {
      backIdUrl = await cloudinaryService.uploadImage(
        File(data.backIdImagePath!),
      );
    }

    // 3. Upload Selfie Image to Cloudinary
    final selfieUrl = await cloudinaryService.uploadImage(
      File(data.selfiePath!),
    );

    // 4. Save URLs & extracted details to Firestore
    await firestoreService.submitVerificationRecord(
      userId: userId,
      data: data,
      idCloudinaryUrl: idUrl,
      backIdCloudinaryUrl: backIdUrl,
      selfieCloudinaryUrl: selfieUrl,
    );
  }
}
