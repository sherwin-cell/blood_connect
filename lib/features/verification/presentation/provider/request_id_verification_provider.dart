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

  /// Possible values:
  /// null
  /// ''
  /// 'unverified'
  /// 'pending'
  /// 'approved'
  /// 'verified'
  /// 'rejected'
  String? _verificationStatus;

  /// Face verification is required before ID verification.
  bool _isFaceVerified = false;

  RequestIdVerificationProvider({
    required this.repository,
    required this.userId,
  });

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  RequestIdVerificationData get data => _data;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  String? get verificationStatus => _verificationStatus;

  bool get isFaceVerified => _isFaceVerified;

  /// The account's ID verification has already been approved.
  bool get isAccountFullyVerified =>
      _verificationStatus == 'approved' || _verificationStatus == 'verified';

  /// The ID verification is currently waiting for PRC/admin review.
  bool get isVerificationPending => _verificationStatus == 'pending';

  /// ID can only be submitted when:
  ///
  /// 1. Face verification has passed.
  /// 2. ID verification has never been submitted,
  ///    or the previous submission was rejected.
  ///
  /// Approved/verified accounts cannot submit another ID.
  bool get canSubmitId {
    if (!_isFaceVerified) {
      return false;
    }

    return _verificationStatus == null ||
        _verificationStatus == '' ||
        _verificationStatus == 'unverified' ||
        _verificationStatus == 'rejected';
  }

  // ---------------------------------------------------------------------------
  // LOAD EXISTING VERIFICATION STATUS
  // ---------------------------------------------------------------------------

  Future<void> loadVerificationStatus() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      debugPrint('');
      debugPrint('==============================================');
      debugPrint('ID VERIFICATION STATUS LOAD');
      debugPrint('==============================================');
      debugPrint('USER ID: $userId');

      // -----------------------------------------------------------------------
      // 1. Load FACE verification status
      // -----------------------------------------------------------------------

      debugPrint('Loading face verification status...');

      final faceVerified = await repository.getFaceVerificationStatus(userId);

      _isFaceVerified = faceVerified;

      debugPrint('FACE VERIFICATION STATUS: $_isFaceVerified');

      // -----------------------------------------------------------------------
      // 2. Load ID verification status
      // -----------------------------------------------------------------------

      debugPrint('Loading ID verification status...');

      final idStatus = await repository.getIdVerificationStatus(userId);

      debugPrint('REPOSITORY ID STATUS: $idStatus');

      _verificationStatus = idStatus;

      debugPrint('LOCAL ID STATUS AFTER LOAD: $_verificationStatus');

      debugPrint('CAN SUBMIT ID: $canSubmitId');

      debugPrint('ACCOUNT FULLY VERIFIED: $isAccountFullyVerified');

      debugPrint('VERIFICATION PENDING: $isVerificationPending');

      debugPrint('==============================================');
      debugPrint('ID VERIFICATION STATUS LOAD COMPLETE');
      debugPrint('==============================================');
      debugPrint('');
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('==============================================');
      debugPrint('ID VERIFICATION STATUS LOAD ERROR');
      debugPrint('==============================================');
      debugPrint('ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      debugPrint('==============================================');
      debugPrint('');

      _errorMessage = 'Failed to load verification status.';
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // ID TYPE
  // ---------------------------------------------------------------------------

  void selectIdType(String idType) {
    _data = _data.copyWith(idType: idType);

    notifyListeners();
  }

  /// Updates the selected ID type locally.
  ///
  /// No database write happens here.
  Future<void> selectIdTypeAndSaveProfile(String idType) async {
    _data = _data.copyWith(idType: idType);

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // FRONT ID
  // ---------------------------------------------------------------------------

  Future<bool> processIdCard(File imageFile) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (!await imageFile.exists()) {
        _errorMessage = 'Government ID image is missing.';
        return false;
      }

      final fileSize = await imageFile.length();

      if (fileSize == 0) {
        _errorMessage = 'Government ID image is empty.';
        return false;
      }

      debugPrint('PROCESS FRONT ID: ${imageFile.path}');

      debugPrint('FRONT ID FILE SIZE: $fileSize bytes');

      _data = _data.copyWith(
        frontIdImage: imageFile.path,
        validationStatus: 'valid',
      );

      _errorMessage = null;

      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      debugPrint('PROCESS FRONT ID ERROR: $e');

      debugPrint('$stackTrace');

      _errorMessage = 'Failed to process ID image. Please retry.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // BACK ID
  // ---------------------------------------------------------------------------

  Future<bool> processBackIdCard(File imageFile) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (!await imageFile.exists()) {
        _errorMessage = 'Back ID image is missing.';
        return false;
      }

      final fileSize = await imageFile.length();

      if (fileSize == 0) {
        _errorMessage = 'Back ID image is empty.';
        return false;
      }

      debugPrint('PROCESS BACK ID: ${imageFile.path}');

      debugPrint('BACK ID FILE SIZE: $fileSize bytes');

      _data = _data.copyWith(backIdImage: imageFile.path);

      _errorMessage = null;

      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      debugPrint('PROCESS BACK ID ERROR: $e');

      debugPrint('$stackTrace');

      _errorMessage = 'Failed to process back of ID. Please retry.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // CONFIRM LOCAL DATA
  // ---------------------------------------------------------------------------

  RequestIdVerificationData confirm() {
    _data = _data.copyWith(submittedAt: DateTime.now());

    notifyListeners();

    return _data;
  }

  // ---------------------------------------------------------------------------
  // SUBMIT ID VERIFICATION
  // ---------------------------------------------------------------------------

  Future<bool> confirmAndSubmit() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _data = _data.copyWith(submittedAt: DateTime.now());

      debugPrint('');
      debugPrint('==============================================');
      debugPrint('SUBMISSION START');
      debugPrint('==============================================');

      debugPrint('USER ID: $userId');

      debugPrint('ID TYPE: ${_data.idType}');

      debugPrint('FRONT ID: ${_data.frontIdImage}');

      debugPrint('BACK ID: ${_data.backIdImage}');

      debugPrint('VALIDATION STATUS: ${_data.validationStatus}');

      debugPrint('FACE VERIFIED: $_isFaceVerified');

      debugPrint('CURRENT ID STATUS BEFORE SAVE: $_verificationStatus');

      // -----------------------------------------------------------------------
      // Save ID submission
      // -----------------------------------------------------------------------

      debugPrint('Starting saveOrUpdateIdSubmission...');

      await repository.saveOrUpdateIdSubmission(userId: userId, data: _data);

      debugPrint('saveOrUpdateIdSubmission COMPLETED');

      // -----------------------------------------------------------------------
      // IMPORTANT:
      //
      // The newly submitted ID is now waiting for PRC/admin review.
      //
      // Do NOT mark it approved here.
      // -----------------------------------------------------------------------

      _verificationStatus = 'pending';

      debugPrint('LOCAL VERIFICATION STATUS SET TO: $_verificationStatus');

      debugPrint('IS PENDING: $isVerificationPending');

      debugPrint('CAN SUBMIT ID AFTER SUBMISSION: $canSubmitId');

      debugPrint(
        'ACCOUNT FULLY VERIFIED AFTER SUBMISSION: '
        '$isAccountFullyVerified',
      );

      debugPrint('==============================================');
      debugPrint('SUBMISSION END');
      debugPrint('==============================================');
      debugPrint('');

      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('==============================================');
      debugPrint('SUBMISSION ERROR');
      debugPrint('==============================================');

      debugPrint('ERROR: $e');

      debugPrint('STACK TRACE:');

      debugPrint('$stackTrace');

      debugPrint('==============================================');
      debugPrint('');

      _errorMessage = 'Failed to submit verification request. Please retry.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // LOADING STATE
  // ---------------------------------------------------------------------------

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
