import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/services/face_verification_api.dart';
import '../../domain/entities/face_verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';

enum FaceVerificationStatus { none, verified, failed, limitReached, idRequired }

/// Selfie step of identity verification.
///
/// On-device face detection/cropping is only a usability pre-check (instant
/// "no face found" feedback without spending an attempt). The match against
/// the user's ID, the daily attempt limit and the write to
/// users/{uid}.faceVerified all happen in the backend.
class VerificationProvider extends ChangeNotifier {
  final IVerificationRepository repository;
  final FaceVerificationApi _api;
  final bool Function() _isSignedIn;

  FaceVerificationData _data = const FaceVerificationData();
  bool _isLoading = false;
  String? _errorMessage;
  FaceVerificationStatus _status = FaceVerificationStatus.none;
  FaceVerificationOutcome? _outcome;

  VerificationProvider({
    required this.repository,
    FaceVerificationApi? api,
    bool Function()? isSignedIn,
  }) : _api = api ?? FaceVerificationApi(),
       _isSignedIn =
           isSignedIn ?? (() => FirebaseAuth.instance.currentUser != null);

  FaceVerificationData get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  FaceVerificationStatus get status => _status;
  bool get isFaceVerified => _status == FaceVerificationStatus.verified;

  /// Last backend answer (null before the first submit).
  FaceVerificationOutcome? get outcome => _outcome;

  /// Clears the previous result before a new attempt.
  void reset() {
    _data = const FaceVerificationData();
    _errorMessage = null;
    _status = FaceVerificationStatus.none;
    _outcome = null;
    notifyListeners();
  }

  /// UX pre-check: is there a face in the selfie at all?
  Future<bool> processSelfie(File imageFile) async {
    _setLoading(true);
    try {
      if (!await imageFile.exists() || await imageFile.length() == 0) {
        _errorMessage = 'Selfie image is missing.';
        return false;
      }

      final faceCount = await repository.countFaces(imageFile);
      if (faceCount == 0) {
        _errorMessage = 'No face detected in selfie.';
        _data = _data.copyWith(
          selfiePath: imageFile.path,
          hasDetectedFace: false,
        );
        return false;
      }

      _data = _data.copyWith(selfiePath: imageFile.path, hasDetectedFace: true);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Face detection failed.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sends the selfie to the backend. Returns true only when the backend
  /// verified the user (or they were already verified).
  Future<bool> submitFaceVerification() async {
    _setLoading(true);
    try {
      if (!_isSignedIn()) {
        _errorMessage = 'User is not authenticated. Please log in again.';
        _status = FaceVerificationStatus.failed;
        return false;
      }

      final selfiePath = _data.selfiePath;
      if (selfiePath == null || selfiePath.isEmpty) {
        _errorMessage = 'Selfie image is missing.';
        _status = FaceVerificationStatus.failed;
        return false;
      }

      final selfieFile = File(selfiePath);
      if (!await selfieFile.exists() || await selfieFile.length() == 0) {
        _errorMessage = 'Selfie image is missing.';
        _status = FaceVerificationStatus.failed;
        return false;
      }

      // Pre-check only: avoid spending an attempt on a photo with no face.
      final croppedSelfie = await repository.cropPrimaryFace(selfieFile);
      if (croppedSelfie == null) {
        _errorMessage =
            'No face detected in selfie. Please retake your selfie.';
        _status = FaceVerificationStatus.failed;
        return false;
      }

      final outcome = await _api.verifySelfie(selfieFile);
      _outcome = outcome;

      if (outcome.passed) {
        _status = FaceVerificationStatus.verified;
        _errorMessage = null;
      } else if (outcome.limitReached) {
        _status = FaceVerificationStatus.limitReached;
        _errorMessage = outcome.message;
      } else if (outcome.idRequired) {
        _status = FaceVerificationStatus.idRequired;
        _errorMessage = outcome.message;
      } else {
        _status = FaceVerificationStatus.failed;
        _errorMessage = outcome.message;
      }
      return outcome.passed;
    } catch (e, stackTrace) {
      debugPrint('Face verification submit error: $e\n$stackTrace');
      _errorMessage = 'Could not verify your selfie. Please try again.';
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
