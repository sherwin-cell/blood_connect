import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/services/ocr_service.dart';
import '../../domain/entities/verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';

enum VerificationStatus { none, pending, approved, rejected }

class VerificationProvider extends ChangeNotifier {
  final IVerificationRepository repository;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  VerificationData _data = const VerificationData();
  bool _isLoading = false;
  String? _errorMessage;

  VerificationStatus _status = VerificationStatus.none;
  StreamSubscription<DocumentSnapshot>? _statusSubscription;
  final StreamController<VerificationStatus> _statusStreamController =
      StreamController<VerificationStatus>.broadcast();

  VerificationProvider({
    required this.repository,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance {
    _initStatusListener();
  }

  // Getters
  VerificationData get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  VerificationStatus get status => _status;

  /// Broadcast stream consumed by screens like [VerificationPendingScreen]
  Stream<VerificationStatus> get statusStream => _statusStreamController.stream;

  // ---------------------------------------------------------------------------
  // Real-time Firestore Status Listener
  // ---------------------------------------------------------------------------

  /// Listens to real-time verification updates from the authenticated user's doc
  void _initStatusListener() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _statusSubscription?.cancel();
    _statusSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              final data = snapshot.data()!;
              final statusStr = data['verificationStatus'] as String? ?? 'none';

              _status = _parseStatus(statusStr);
              _statusStreamController.add(_status);
              notifyListeners();
            }
          },
          onError: (error) {
            _errorMessage = 'Failed to sync verification status: $error';
            notifyListeners();
          },
        );
  }

  VerificationStatus _parseStatus(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'pending':
      case 'under_review':
        return VerificationStatus.pending;
      case 'approved':
      case 'verified':
        return VerificationStatus.approved;
      case 'rejected':
      case 'failed':
        return VerificationStatus.rejected;
      default:
        return VerificationStatus.none;
    }
  }

  // ---------------------------------------------------------------------------
  // ID & Selfie Operations
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Submission Pipeline (Local Embeddings Execution)
  // ---------------------------------------------------------------------------

  /// Submits verification using a provided userId.
  ///
  /// Flow: Local face crop → Local embedding compare → Score Check (>= 75% Auto-Approves) → Repository Save
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

      // Crop face bounding boxes for localized feature extraction
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

      // Perform local face feature vector comparison
      final matchResult = await repository.compareFaces(
        idCardFace: croppedId,
        selfieFace: croppedSelfie,
      );

      if (matchResult['success'] != true) {
        _errorMessage =
            matchResult['error'] as String? ?? 'Face matching failed.';
        debugPrint('Local face comparison failed: $_errorMessage');
        return false;
      }

      final faceMatchScore = (matchResult['faceMatchConfidence'] as num?)
          ?.toDouble();
      final faceMatchPassed = matchResult['faceMatchPassed'] == true;

      final finalData = _data.copyWith(
        faceMatchConfidence: faceMatchScore,
        faceMatchPassed: faceMatchPassed,
        verificationProvider: 'local_facenet',
      );
      _data = finalData;

      // Determine status: If match passes (>= 75%), auto-approve. Otherwise, send to review.
      final String determinedStatus = faceMatchPassed
          ? 'approved'
          : 'under_review';

      debugPrint(
        'Face Match Result — Score: ${faceMatchScore?.toStringAsFixed(1)}%, Passed: $faceMatchPassed, Status: $determinedStatus',
      );

      try {
        await repository.submitVerification(
          userId: userId,
          data: finalData,
          status: determinedStatus,
        );
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
      _status = _parseStatus(determinedStatus);
      _statusStreamController.add(_status);
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
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _errorMessage = 'User is not authenticated. Please log in again.';
      notifyListeners();
      return false;
    }
    return await submit(currentUser.uid);
  }

  // ---------------------------------------------------------------------------
  // Helpers & Cleanup
  // ---------------------------------------------------------------------------

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _statusStreamController.close();
    super.dispose();
  }
}
