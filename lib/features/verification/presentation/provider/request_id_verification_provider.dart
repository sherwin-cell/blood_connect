import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../domain/entities/request_id_verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';

class RequestIdVerificationProvider extends ChangeNotifier {
  final IVerificationRepository repository;
  final String userId;

  RequestIdVerificationData _data = const RequestIdVerificationData();
  bool _isLoading = false;
  String? _errorMessage;
  String?
  _verificationStatus; // null, 'pending', 'approved', 'rejected', 'unverified', ''

  RequestIdVerificationProvider({
    required this.repository,
    required this.userId,
  });

  RequestIdVerificationData get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get verificationStatus => _verificationStatus;

  bool get isAccountFullyVerified =>
      _verificationStatus == 'approved' || _verificationStatus == 'verified';

  bool get isVerificationPending => _verificationStatus == 'pending';

  bool get canSubmitId =>
      _verificationStatus == null ||
      _verificationStatus == 'unverified' ||
      _verificationStatus == '' ||
      _verificationStatus == 'rejected';

  Future<void> loadVerificationStatus() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final status = await repository.getIdVerificationStatus(userId);
      debugPrint('DEBUG REPO STATUS: $status');
      _verificationStatus = status;
    } catch (e) {
      debugPrint('DEBUG ERROR: $e');
      _errorMessage = 'Failed to load verification status.';
    } finally {
      _setLoading(false);
      debugPrint('DEBUG FINAL CAN SUBMIT: $canSubmitId');
    }
  }

  void selectIdType(String idType) {
    _data = _data.copyWith(idType: idType);
    notifyListeners();
  }

  /// Fixed: Removed premature database write (BC-BUG-002) so it only updates local state.
  Future<void> selectIdTypeAndSaveProfile(String idType) async {
    _data = _data.copyWith(idType: idType);
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

      _data = _data.copyWith(
        frontIdImage: imageFile.path,
        validationStatus: 'valid',
      );
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to process ID image. Please retry.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> processBackIdCard(File imageFile) async {
    _setLoading(true);
    try {
      _data = _data.copyWith(backIdImage: imageFile.path);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to process back of ID. Please retry.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  RequestIdVerificationData confirm() {
    _data = _data.copyWith(submittedAt: DateTime.now());
    notifyListeners();
    return _data;
  }

  Future<bool> confirmAndSubmit() async {
    _setLoading(true);
    try {
      _data = _data.copyWith(submittedAt: DateTime.now());

      await repository.saveOrUpdateIdSubmission(userId: userId, data: _data);

      _verificationStatus = 'pending';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to submit verification request. Please retry.';
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
