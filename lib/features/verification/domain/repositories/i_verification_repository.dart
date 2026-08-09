import 'dart:io';
import '../entities/verification_data.dart';

abstract class IVerificationRepository {
  /// Extract name, ID number, birth date, and gender from an ID card image file.
  /// Values can be null if the OCR scanner could not reliably parse a specific field.
  Future<Map<String, String?>> processIdOcr(File imageFile);

  /// Check if a face exists in the captured selfie file
  Future<bool> detectFace(File imageFile);

  /// Count faces in an image (ID or selfie).
  Future<int> countFaces(File imageFile);

  /// Crop the primary face from an image for ARSA comparison.
  Future<File?> cropPrimaryFace(File imageFile);

  /// Upload photos and create a submission record in Firebase
  Future<void> submitVerification({
    required String userId,
    required VerificationData data,
  });
}
