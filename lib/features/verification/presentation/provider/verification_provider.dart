import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/face_verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';

enum FaceVerificationStatus { none, verified, failed }

class VerificationProvider extends ChangeNotifier {
  final IVerificationRepository repository;
  final FirebaseAuth _auth;

  FaceVerificationData _data = const FaceVerificationData();
  bool _isLoading = false;
  String? _errorMessage;
  FaceVerificationStatus _status = FaceVerificationStatus.none;

  VerificationProvider({
    required this.repository,
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  FaceVerificationData get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  FaceVerificationStatus get status => _status;
  bool get isFaceVerified => _status == FaceVerificationStatus.verified;

  Future<bool> processSelfie(File imageFile) async {
    _setLoading(true);
    try {
      if (!await imageFile.exists()) {
        _errorMessage = 'Selfie image is missing.';
        return false;
      }
      if (await imageFile.length() == 0) {
        _errorMessage = 'Selfie image is empty.';
        return false;
      }

      final faceCount = await repository.countFaces(imageFile);
      if (faceCount == 0) {
        _errorMessage = 'No face detected in selfie.';
        _data = _data.copyWith(
          selfiePath: imageFile.path,
          hasDetectedFace: false,
          faceMatchPassed: false,
          verificationResult: 'failed',
        );
        return false;
      }

      _data = _data.copyWith(
        selfiePath: imageFile.path,
        hasDetectedFace: true,
      );
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Face detection failed.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Completes account face verification automatically (no admin review).
  Future<bool> submitFaceVerification() async {
    _setLoading(true);
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _errorMessage = 'User is not authenticated. Please log in again.';
        return false;
      }

      if (_data.selfiePath == null || _data.selfiePath!.isEmpty) {
        _errorMessage = 'Selfie image is missing.';
        return false;
      }

      final selfieFile = File(_data.selfiePath!);
      if (!await selfieFile.exists() || await selfieFile.length() == 0) {
        _errorMessage = 'Selfie image is missing.';
        return false;
      }

      final croppedSelfie = await repository.cropPrimaryFace(selfieFile);
      if (croppedSelfie == null) {
        _errorMessage =
            'No face detected in selfie. Please retake your selfie.';
        _status = FaceVerificationStatus.failed;
        return false;
      }

      final passed = _data.hasDetectedFace;
      final finalData = _data.copyWith(
        faceMatchPassed: passed,
        verificationProvider: 'local_liveness',
        verificationResult: passed ? 'verified' : 'failed',
        verifiedAt: DateTime.now(),
      );
      _data = finalData;

      await repository.saveFaceVerification(
        userId: currentUser.uid,
        data: finalData,
      );

      _errorMessage = null;
      _status = passed
          ? FaceVerificationStatus.verified
          : FaceVerificationStatus.failed;
      return passed;
    } catch (e, stackTrace) {
      debugPrint('Face verification submit error: $e');
      debugPrint('$stackTrace');
      final msg = e.toString().toLowerCase();
      if (msg.contains('cloudinary')) {
        _errorMessage = 'Cloudinary upload failed. Please try again.';
      } else {
        _errorMessage = 'Could not save face verification. Please try again.';
      }
      _status = FaceVerificationStatus.failed;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
