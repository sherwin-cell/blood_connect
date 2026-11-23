import 'dart:io';

import '../../../../core/services/firestore_service.dart';
import '../../domain/entities/request_id_verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';
import '../../../../core/services/secure_upload_api.dart';
import '../services/face_detector_service.dart';

class VerificationRepositoryImpl implements IVerificationRepository {
  final FaceDetectorService faceDetectorService;
  final SecureUploadApi secureUploadApi;
  final FirestoreService firestoreService;

  VerificationRepositoryImpl({
    required this.faceDetectorService,
    required this.secureUploadApi,
    required this.firestoreService,
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
  Future<bool> getFaceVerificationStatus(String userId) async {
    return await firestoreService.getFaceVerificationStatus(userId);
  }

  @override
  Future<({String frontUrl, String? backUrl})> uploadRequestIdImages({
    required String frontIdPath,
    String? backIdPath,
  }) async {
    // Private uploads through the backend: these are secure:// references,
    // not public links (see SecureUploadApi).
    final frontUrl = await secureUploadApi.upload(
      File(frontIdPath),
      SecureUploadKind.idFront,
    );

    String? backUrl;

    if (backIdPath != null && backIdPath.isNotEmpty) {
      backUrl = await secureUploadApi.upload(
        File(backIdPath),
        SecureUploadKind.idBack,
      );
    }

    return (frontUrl: frontUrl, backUrl: backUrl);
  }

  @override
  Future<String?> getIdVerificationStatus(String userId) async {
    return await firestoreService.getIdVerificationStatus(userId);
  }

  // ==========================================
  // ONE-TIME ID SUBMISSION
  // ==========================================

  @override
  Future<String> saveOrUpdateIdSubmission({
    required String userId,
    required RequestIdVerificationData data,
  }) async {
    // Step 1: Check whether the user already
    // has a saved ID submission.
    //
    // This also recognizes legacy records
    // previously marked "approved".

    final existingSubmission = await firestoreService
        .getLatestSavedIdSubmissionForUser(userId);

    if (existingSubmission != null) {
      final frontUrl = existingSubmission['frontIdImageUrl'];

      final backUrl = existingSubmission['backIdImageUrl'];

      final hasFront = frontUrl is String && frontUrl.trim().isNotEmpty;

      final hasBack = backUrl is String && backUrl.trim().isNotEmpty;

      if (hasFront && hasBack) {
        // Reuse the original submission.
        // Do not upload images again.
        // Do not overwrite the saved ID.

        return userId;
      }

      // An incomplete record should not be
      // silently replaced or treated as valid.
      throw StateError(
        'An incomplete ID submission already exists. '
        'Please contact support.',
      );
    }

    // Step 2: Validate the local ID images.

    final frontPath = data.frontIdImage;
    final backPath = data.backIdImage;

    if (frontPath == null || frontPath.trim().isEmpty) {
      throw Exception('Front ID image is missing.');
    }

    if (backPath == null || backPath.trim().isEmpty) {
      throw Exception('Back ID image is missing.');
    }

    final frontFile = File(frontPath);
    final backFile = File(backPath);

    if (!await frontFile.exists() || await frontFile.length() == 0) {
      throw Exception('Front ID image is invalid.');
    }

    if (!await backFile.exists() || await backFile.length() == 0) {
      throw Exception('Back ID image is invalid.');
    }

    // Step 3: Upload only for first-time users.

    final uploadedUrls = await uploadRequestIdImages(
      frontIdPath: frontPath,
      backIdPath: backPath,
    );

    // Step 4: Save one ID record in Firestore.
    //
    // FirestoreService must enforce
    // create-once behavior atomically.

    return await firestoreService.saveIdVerificationSubmission(
      userId: userId,
      frontUrl: uploadedUrls.frontUrl,
      backUrl: uploadedUrls.backUrl,
      data: data,
    );
  }
}
