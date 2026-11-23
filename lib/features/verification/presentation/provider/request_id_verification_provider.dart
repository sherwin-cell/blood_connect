import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/entities/request_id_verification_data.dart';
import '../../domain/repositories/i_verification_repository.dart';
import '../../../../core/constants/statuses.dart';

/// Manages the one-time ID submission flow.
/// A submitted ID is reusable; it is not a claim that the ID is authentic
/// or that the user's donor/blood request has been approved by PRC.
class RequestIdVerificationProvider extends ChangeNotifier {
  final IVerificationRepository repository;
  final String userId;

  RequestIdVerificationProvider({
    required this.repository,
    required this.userId,
  });

  RequestIdVerificationData _data = const RequestIdVerificationData();
  bool _isLoading = false;
  String? _errorMessage;
  String? _verificationStatus;
  bool _statusLoaded = false;

  RequestIdVerificationData get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get verificationStatus => _verificationStatus;

  /// Kept for compatibility with existing UI. This now means only that
  /// an ID was submitted, NOT that the account is fully verified.
  @Deprecated(
    'Use hasSubmittedId instead; ID submission is not account approval.',
  )
  bool get isAccountFullyVerified => hasSubmittedId;

  bool get hasSubmittedId =>
      _verificationStatus == IdVerificationStatus.submitted;

  /// Kept for compatibility with older screens. There is no separate
  /// ID approval queue in the one-time submission workflow.
  bool get isVerificationPending => false;

  /// The ID comes first in identity verification (the backend compares the
  /// selfie against it), so no face verification is required here.
  bool get canSubmitId =>
      _statusLoaded && !hasSubmittedId && !_isLoading && _errorMessage == null;

  String? _normalizeStatus(String? status) {
    switch (status?.trim().toLowerCase()) {
      case IdVerificationStatus.submitted:
      case IdVerificationStatus.approved:
      case IdVerificationStatus.legacyVerified:
      case IdVerificationStatus.legacyPending:
        // Legacy saved IDs count as submitted; the repository/service
        // must check that the actual saved ID record exists.
        return IdVerificationStatus.submitted;
      case null:
      case '':
      case 'unverified':
      case IdVerificationStatus.rejected:
        return null;
      default:
        // Unknown status must not silently permit another upload.
        throw StateError('Unexpected ID submission status: $status');
    }
  }

  Future<void> loadVerificationStatus() async {
    _setLoading(true);
    _errorMessage = null;
    _statusLoaded = false;
    try {
      final status = await repository.getIdVerificationStatus(userId);
      _verificationStatus = _normalizeStatus(status);
      _statusLoaded = true;
      debugPrint('ID submission status: $_verificationStatus');
    } catch (e, stackTrace) {
      debugPrint('Failed to load ID submission status: $e\n$stackTrace');
      _errorMessage = 'Failed to load ID submission status. Please retry.';
    } finally {
      _setLoading(false);
    }
  }

  void selectIdType(String idType) {
    _data = _data.copyWith(idType: idType);
    notifyListeners();
  }

  Future<void> selectIdTypeAndSaveProfile(String idType) async {
    selectIdType(idType);
  }

  Future<bool> processIdCard(File imageFile) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      if (!await imageFile.exists() || await imageFile.length() == 0) {
        _errorMessage = 'Government ID image is missing or empty.';
        return false;
      }
      _data = _data.copyWith(
        frontIdImage: imageFile.path,
        // Local file validation only; not proof of ID authenticity.
        validationStatus: 'valid',
      );
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('Failed to process front ID: $e\n$stackTrace');
      _errorMessage = 'Failed to process ID image. Please retry.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> processBackIdCard(File imageFile) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      if (!await imageFile.exists() || await imageFile.length() == 0) {
        _errorMessage = 'Back ID image is missing or empty.';
        return false;
      }
      _data = _data.copyWith(backIdImage: imageFile.path);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('Failed to process back ID: $e\n$stackTrace');
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
    if (_isLoading) return false;
    _setLoading(true);
    _errorMessage = null;
    try {
      if (!_statusLoaded) {
        _verificationStatus = _normalizeStatus(
          await repository.getIdVerificationStatus(userId),
        );
        _statusLoaded = true;
      }
      if (hasSubmittedId) {
        // No new upload is needed; existing ID will be reused.
        return true;
      }
      _data = _data.copyWith(submittedAt: DateTime.now());
      await repository.saveOrUpdateIdSubmission(userId: userId, data: _data);
      // Reload from Firestore rather than assuming a successful write
      // means an approved/verified account.
      final savedStatus = _normalizeStatus(
        await repository.getIdVerificationStatus(userId),
      );
      if (savedStatus != IdVerificationStatus.submitted) {
        throw StateError('ID submission could not be confirmed.');
      }
      _verificationStatus = IdVerificationStatus.submitted;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('ID submission failed: $e\n$stackTrace');
      _errorMessage = 'Failed to submit ID. Please retry.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
