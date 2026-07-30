import 'dart:io';
import 'package:flutter/foundation.dart';
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

  // ==========================================
  // UPDATED: Added method for manual corrections
  // ==========================================

  /// Updates the internal state with manual corrections made by the user
  /// on the Review ID Screen.
  void updateExtractedData({
    required String correctedName,
    required String correctedIdNumber,
  }) {
    _data = _data.copyWith(
      extractedName: correctedName,
      idNumber: correctedIdNumber,
    );
    // In strict Clean Architecture/MVVM, we notify because the Review
    // Screen is usually navigating away, and this data is needed
    // for the final Firestore submission.
    notifyListeners();
  }

  // ==========================================

  Future<bool> processIdCard(File imageFile) async {
    _setLoading(true);
    try {
      final ocrResults = await repository.processIdOcr(imageFile);

      _data = _data.copyWith(
        idImagePath: imageFile.path,
        extractedName: ocrResults['extractedName'],
        idNumber: ocrResults['idNumber'],
      );
      _errorMessage = null;
      return true; // ✅ Success!
    } catch (e) {
      _errorMessage = 'Failed to read text from ID. Please retry.';
      return false; // ❌ OCR / Image processing failed
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

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
