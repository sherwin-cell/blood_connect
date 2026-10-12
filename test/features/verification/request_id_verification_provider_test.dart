import 'dart:io';

import 'package:blood_connect/features/verification/domain/entities/request_id_verification_data.dart';
import 'package:blood_connect/features/verification/domain/repositories/i_verification_repository.dart';
import 'package:blood_connect/features/verification/presentation/provider/request_id_verification_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVerificationRepository implements IVerificationRepository {
  @override
  Future<bool> detectFace(File imageFile) async => true;

  @override
  Future<int> countFaces(File imageFile) async => 1;

  @override
  Future<File?> cropPrimaryFace(File imageFile) async => imageFile;

  @override
  Future<Map<String, dynamic>> compareFaces({
    required File idCardFace,
    required File selfieFace,
  }) async => {'success': true};

  @override
  Future<void> saveFaceVerification({
    required String userId,
    required dynamic data,
  }) async {}

  @override
  Future<bool> getFaceVerificationStatus(String userId) async => true;

  @override
  Future<({String frontUrl, String? backUrl})> uploadRequestIdImages({
    required String frontIdPath,
    String? backIdPath,
  }) async => (frontUrl: 'https://example.com/front.jpg', backUrl: 'https://example.com/back.jpg');

  @override
  Future<String?> getIdVerificationStatus(String userId) async => 'pending';

  @override
  Future<String> saveOrUpdateIdSubmission({
    required String userId,
    required RequestIdVerificationData data,
  }) async => 'submission-123';

  @override
  Future<void> offerToDonate({
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorContact,
    required String donorBloodType,
  }) async {}
}

void main() {
  group('RequestIdVerificationData', () {
    test('isComplete requires idType, both image paths, and validationStatus', () {
      final dir = Directory.systemTemp.createTempSync('id_verification_test_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final frontPath = '${dir.path}/front.jpg';
      final backPath = '${dir.path}/back.jpg';
      File(frontPath).writeAsStringSync('front');
      File(backPath).writeAsStringSync('back');

      final completeData = RequestIdVerificationData(
        idType: 'Driver License',
        frontIdImage: frontPath,
        backIdImage: backPath,
        validationStatus: 'valid',
      );

      expect(completeData.isComplete, isTrue);
      final missingValidation = RequestIdVerificationData(
        idType: 'Driver License',
        frontIdImage: frontPath,
        backIdImage: backPath,
        validationStatus: null,
      );

      final missingBackImage = RequestIdVerificationData(
        idType: 'Driver License',
        frontIdImage: frontPath,
        backIdImage: null,
        validationStatus: 'valid',
      );

      expect(missingValidation.isComplete, isFalse);
      expect(missingBackImage.isComplete, isFalse);
    });
  });

  group('RequestIdVerificationProvider', () {
    test('successful submission keeps the status pending until admin review', () async {
      final dir = Directory.systemTemp.createTempSync('id_verification_provider_test_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final frontPath = '${dir.path}/front.jpg';
      final backPath = '${dir.path}/back.jpg';
      File(frontPath).writeAsStringSync('front');
      File(backPath).writeAsStringSync('back');

      final provider = RequestIdVerificationProvider(
        repository: _FakeVerificationRepository(),
        userId: 'user-123',
      );

      provider.selectIdType('Driver License');
      await provider.processIdCard(File(frontPath));
      await provider.processBackIdCard(File(backPath));
      await provider.confirmAndSubmit();

      expect(provider.verificationStatus, 'pending');
      expect(provider.canSubmitId, isFalse);
    });
  });
}
