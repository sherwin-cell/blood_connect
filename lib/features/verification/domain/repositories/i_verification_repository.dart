import 'dart:io';
import '../entities/verification_data.dart';

abstract class IVerificationRepository {
  /// Extract name and ID number from an ID card image file
  Future<Map<String, String>> processIdOcr(File imageFile);

  /// Check if a face exists in the captured selfie file
  Future<bool> detectFace(File imageFile);

  /// Upload photos and create a submission record in Firebase
  Future<void> submitVerification({
    required String userId,
    required VerificationData data,
  });
}
