import 'dart:io';
import '../entities/request_id_verification_data.dart';

abstract class IVerificationRepository {
  /// Check if a face exists in the captured selfie file
  Future<bool> detectFace(File imageFile);

  /// Count faces in an image (selfie).
  Future<int> countFaces(File imageFile);

  /// Crop the primary face from an image (selfie pre-check before upload).
  Future<File?> cropPrimaryFace(File imageFile);

  /// Uploads ID images privately through the backend and returns their
  /// secure:// references. Does not write Firestore.
  Future<({String frontUrl, String? backUrl})> uploadRequestIdImages({
    required String frontIdPath,
    String? backIdPath,
  });

  /// Get the user's current ID verification status ('pending', 'approved', 'rejected', or null)
  Future<String?> getIdVerificationStatus(String userId);

  /// Save or update the ID verification submission and return the submission ID.
  Future<String> saveOrUpdateIdSubmission({
    required String userId,
    required RequestIdVerificationData data,
  });
}
