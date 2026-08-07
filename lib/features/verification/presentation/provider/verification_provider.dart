import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/services/ocr_service.dart';
import '../../domain/entities/verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';

class VerificationProvider extends ChangeNotifier {
  final IVerificationRepository repository;

  VerificationProvider({required this.repository});

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
  /// on the Review / ReviewAll Screen.
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
      final ocrResults = await repository.processIdOcr(imageFile);

      _data = _data.copyWith(
        idImagePath: imageFile.path,
        extractedName: ocrResults['extractedName'],
        extractedBirthDate: ocrResults['extractedBirthDate'],
        extractedGender: ocrResults['extractedGender'],
        idNumber: ocrResults['idNumber'],
      );
      _errorMessage = null;
      return true; // ✅ Success!
    } on NoIdDetectedException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Failed to read text from ID. Please retry.';
      return false; // ❌ OCR / Image processing failed
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================
  // Process Back ID Card
  // ==========================================
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
      final hasFace = await repository.detectFace(imageFile);
      _data = _data.copyWith(
        selfiePath: imageFile.path,
        hasDetectedFace: hasFace,
      );
      _errorMessage = hasFace ? null : 'No face detected in selfie.';
      return hasFace;
    } catch (e) {
      _errorMessage = 'Face detection failed.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Submits verification using a provided userId
  Future<bool> submit(String userId) async {
    _setLoading(true);
    try {
      await repository.submitVerification(userId: userId, data: _data);
      return true;
    } catch (e) {
      _errorMessage = 'Submission failed. Please check connection.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================
  // Convenient wrapper for ReviewAllScreen
  // ==========================================
  /// Automatically fetches the logged-in Firebase user ID and submits.
  Future<bool> submitAllDetails() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _errorMessage = 'User is not authenticated. Please log in again.';
      notifyListeners();
      return false;
    }
    return await submit(currentUser.uid);
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
