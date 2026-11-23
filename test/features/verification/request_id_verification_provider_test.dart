import 'package:blood_connect/core/constants/statuses.dart';
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
  Future<bool> getFaceVerificationStatus(String userId) async => true;

  @override
  Future<({String frontUrl, String? backUrl})> uploadRequestIdImages({
    required String frontIdPath,
    String? backIdPath,
  }) async => (
    frontUrl: 'secure://image/blood_connect_private/u1/id_front/a.jpg',
    backUrl: 'secure://image/blood_connect_private/u1/id_back/b.jpg',
  );

  @override
  Future<String?> getIdVerificationStatus(String userId) async => 'pending';

  @override
  Future<String> saveOrUpdateIdSubmission({
    required String userId,
    required RequestIdVerificationData data,
  }) async => 'submission-123';
}

void main() {
  group('RequestIdVerificationData', () {
    test(
      'isComplete requires idType, both image paths, and validationStatus',
      () {
        final dir = Directory.systemTemp.createTempSync(
          'id_verification_test_',
        );
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
        // validationStatus is optional: it is filled in later by the review.
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

        expect(missingValidation.isComplete, isTrue);
        expect(missingBackImage.isComplete, isFalse);
      },
    );
  });

  group('RequestIdVerificationProvider', () {
    test(
      'successful submission marks the ID as submitted until admin review',
      () async {
        final dir = Directory.systemTemp.createTempSync(
          'id_verification_provider_test_',
        );
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

        expect(provider.verificationStatus, IdVerificationStatus.submitted);
        expect(provider.canSubmitId, isFalse);
      },
    );
  });
}
