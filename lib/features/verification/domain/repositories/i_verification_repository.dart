import 'dart:io';
import '../entities/face_verification_data.dart';
import '../entities/request_id_verification_data.dart';

abstract class IVerificationRepository {
  /// Check if a face exists in the captured selfie file
  Future<bool> detectFace(File imageFile);

  /// Count faces in an image (selfie).
  Future<int> countFaces(File imageFile);

  /// Crop the primary face from an image for face embedding comparison.
  Future<File?> cropPrimaryFace(File imageFile);

  /// Compares cropped ID face against cropped Selfie face using local embeddings.
  Future<Map<String, dynamic>> compareFaces({
    required File idCardFace,
    required File selfieFace,
  });

  /// Uploads the selfie and stores automatic face verification on the user account.
  Future<void> saveFaceVerification({
    required String userId,
    required FaceVerificationData data,
  });

  // ==========================================
  // NEW: Get Face Verification status (Prerequisite)
  // ==========================================
  /// Checks if users/{uid}.faceVerified is true
  Future<bool> getFaceVerificationStatus(String userId);

  /// Uploads request ID images to Cloudinary. Does not write Firestore.
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

  /// Allows an approved donor to submit an offer to help an active blood request
  Future<void> offerToDonate({
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorContact,
    required String donorBloodType,
  });
}
