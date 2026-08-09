import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/services/arsa_face_service.dart';
import '../../data/services/ocr_service.dart';
import '../../domain/entities/verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';

class VerificationProvider extends ChangeNotifier {
  final IVerificationRepository repository;
  final ArsaFaceService arsaFaceService;

  VerificationProvider({
    required this.repository,
    required this.arsaFaceService,
  });

  VerificationData _data = const VerificationData();
  bool _isLoading = false;
  String? _errorMessage;

  VerificationData get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setIdType(String type) {
    _data = _data.copyWith(idType: type);
    notifyListeners();
  }

  /// Updates the internal state with manual corrections made by the user
  void updateExtractedData({
    String? correctedName,
    String? correctedBirthDate,
    String? correctedGender,
    String? correctedIdNumber,
  }) {
    _data = _data.copyWith(
      extractedName: correctedName ?? _data.extractedName,
      extractedBirthDate: correctedBirthDate ?? _data.extractedBirthDate,
      extractedGender: correctedGender ?? _data.extractedGender,
      idNumber: correctedIdNumber ?? _data.idNumber,
    );
    notifyListeners();
  }

  Future<bool> processIdCard(File imageFile) async {
    _setLoading(true);
    try {
      if (!await imageFile.exists()) {
        _errorMessage = 'Government ID image is missing.';
        return false;
      }
      if (await imageFile.length() == 0) {
        _errorMessage = 'Government ID image is empty.';
        return false;
      }

      final idFaceCount = await repository.countFaces(imageFile);
      if (idFaceCount == 0) {
        _errorMessage =
            'No face detected on the government ID. '
            'Align the ID so the photo is clear and try again.';
        return false;
      }
      if (idFaceCount > 1) {
        _errorMessage =
            'Multiple faces detected on the government ID. '
            'Capture only your ID card.';
        return false;
      }

      final ocrResults = await repository.processIdOcr(imageFile);

      _data = _data.copyWith(
        idImagePath: imageFile.path,
        extractedName: ocrResults['extractedName'],
        extractedBirthDate: ocrResults['extractedBirthDate'],
        extractedGender: ocrResults['extractedGender'],
        idNumber: ocrResults['idNumber'],
      );
      _errorMessage = null;
      return true;
    } on NoIdDetectedException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Failed to read text from ID. Please retry.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> processBackIdCard(File imageFile) async {
    _setLoading(true);
    try {
      _data = _data.copyWith(backIdImagePath: imageFile.path);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to process back of ID. Please retry.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

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
        );
        return false;
      }
      if (faceCount > 1) {
        _errorMessage =
            'Multiple faces detected in selfie. Only one face should be visible.';
        _data = _data.copyWith(
          selfiePath: imageFile.path,
          hasDetectedFace: false,
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

  /// Submits verification using a provided userId.
  ///
  /// Flow: ARSA face compare → Cloudinary upload → Firestore save.
  /// Does not upload/save if ARSA fails.
  Future<bool> submit(String userId) async {
    _setLoading(true);
    try {
      debugPrint('========================================');
      debugPrint('=== VERIFICATION START ===');
      debugPrint('userId: $userId');
      debugPrint('idImagePath: ${_data.idImagePath}');
      debugPrint('selfiePath: ${_data.selfiePath}');
      debugPrint('========================================');

      if (_data.idImagePath == null || _data.idImagePath!.isEmpty) {
        _errorMessage = 'Government ID image is missing.';
        return false;
      }
      if (_data.selfiePath == null || _data.selfiePath!.isEmpty) {
        _errorMessage = 'Selfie image is missing.';
        return false;
      }

      final idFile = File(_data.idImagePath!);
      final selfieFile = File(_data.selfiePath!);

      if (!await idFile.exists()) {
        _errorMessage = 'Government ID image is missing.';
        return false;
      }
      if (!await selfieFile.exists()) {
        _errorMessage = 'Selfie image is missing.';
        return false;
      }
      if (await idFile.length() == 0) {
        _errorMessage = 'Government ID image is empty.';
        return false;
      }
      if (await selfieFile.length() == 0) {
        _errorMessage = 'Selfie image is empty.';
        return false;
      }

      // Crop faces so ARSA receives clear face images (ID cards often fail
      // with HTTP 400 "Could not detect faces in one or both images").
      final croppedId = await repository.cropPrimaryFace(idFile);
      final croppedSelfie = await repository.cropPrimaryFace(selfieFile);

      if (croppedId == null) {
        _errorMessage =
            'No face detected on the government ID. '
            'Please recapture a clearer ID photo.';
        return false;
      }
      if (croppedSelfie == null) {
        _errorMessage =
            'No face detected in selfie. Please retake your selfie.';
        return false;
      }

      final arsaResult = await arsaFaceService.compareFaces(
        idImage: croppedId,
        selfieImage: croppedSelfie,
      );

      if (arsaResult['success'] != true) {
        _errorMessage = _mapArsaError(arsaResult);
        debugPrint('ARSA comparison failed: $_errorMessage');
        return false;
      }

      final faceMatchScore = (arsaResult['faceMatchScore'] as num?)?.toDouble();
      final faceMatchPassed = arsaResult['faceMatchPassed'] == true;
      final raw = arsaResult['raw'];

      final finalData = _data.copyWith(
        faceMatchConfidence: faceMatchScore,
        faceMatchPassed: faceMatchPassed,
        verificationProvider: 'arsa',
        arsaRawResponse: raw is Map<String, dynamic> ? raw : null,
      );
      _data = finalData;

      debugPrint(
        'ARSA OK — score: $faceMatchScore, passed: $faceMatchPassed',
      );

      try {
        await repository.submitVerification(userId: userId, data: finalData);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('cloudinary')) {
          _errorMessage = 'Cloudinary upload failed. Please try again.';
        } else {
          _errorMessage = 'Firestore save failed. Please try again.';
        }
        return false;
      }

      _errorMessage = null;
      return true;
    } catch (e, stackTrace) {
      debugPrint('Verification submit error: $e');
      debugPrint('$stackTrace');
      _errorMessage = 'Submission failed. Please check connection.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> submitAllDetails() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _errorMessage = 'User is not authenticated. Please log in again.';
      notifyListeners();
      return false;
    }
    return await submit(currentUser.uid);
  }

  String _mapArsaError(Map<String, dynamic> arsaResult) {
    final code = arsaResult['errorCode'] as String?;
    final message = arsaResult['error'] as String?;

    switch (code) {
      case 'missing_id':
        return 'Government ID image is missing.';
      case 'missing_selfie':
        return 'Selfie image is missing.';
      case 'empty_id':
        return 'Government ID image is empty.';
      case 'empty_selfie':
        return 'Selfie image is empty.';
      case 'invalid_image':
        return message ?? 'Invalid image file.';
      case 'no_face':
        return message ??
            'Could not detect faces in one or both images. '
                'Please recapture clearer photos.';
      case 'multiple_faces':
        return message ?? 'Multiple faces detected.';
      case 'auth':
        return 'Face verification authentication failed.';
      case 'not_found':
        return 'Face verification service endpoint not found.';
      case 'rate_limit':
        return 'Face verification rate limit exceeded. Try again later.';
      case 'server':
        return 'Face verification server error. Please try again.';
      case 'timeout':
        return 'Face verification timed out. Please try again.';
      case 'network':
        return 'Network error during face verification.';
      case 'invalid_json':
        return 'Invalid response from face verification service.';
      default:
        return message ??
            'Face verification failed (HTTP ${arsaResult['httpStatus']}).';
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
