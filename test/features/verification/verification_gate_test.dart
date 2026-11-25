import 'dart:io';

import 'package:blood_connect/core/constants/statuses.dart';
import 'package:blood_connect/features/profile/domain/user_profile_model.dart';
import 'package:blood_connect/features/verification/domain/entities/request_id_verification_data.dart';
import 'package:blood_connect/features/verification/domain/repositories/i_verification_repository.dart';
import 'package:blood_connect/features/verification/presentation/verification_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeVerificationRepository implements IVerificationRepository {
  _FakeVerificationRepository(this.idStatus);

  /// What getIdVerificationStatus answers ('submitted' = both photos).
  final String? idStatus;

  @override
  Future<String?> getIdVerificationStatus(String userId) async => idStatus;

  @override
  Future<bool> detectFace(File imageFile) async => true;

  @override
  Future<int> countFaces(File imageFile) async => 1;

  @override
  Future<File?> cropPrimaryFace(File imageFile) async => imageFile;

  @override
  Future<bool> getFaceVerificationStatus(String userId) async => false;

  @override
  Future<({String frontUrl, String? backUrl})> uploadRequestIdImages({
    required String frontIdPath,
    String? backIdPath,
  }) async => throw UnimplementedError();

  @override
  Future<String> saveOrUpdateIdSubmission({
    required String userId,
    required RequestIdVerificationData data,
  }) async => throw UnimplementedError();
}

UserProfile _profile({required bool faceVerified}) => UserProfile(
  uid: 'u1',
  email: 'u1@example.test',
  phoneNumber: '09123456789',
  bloodType: 'A+',
  faceVerified: faceVerified,
);

const _formKey = ValueKey('application-form');

Future<void> _tapEntry(
  WidgetTester tester, {
  required bool faceVerified,
  required String? idStatus,
}) async {
  await tester.pumpWidget(
    Provider<IVerificationRepository>.value(
      value: _FakeVerificationRepository(idStatus),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => VerificationGate.open(
                context,
                userId: 'u1',
                profile: _profile(faceVerified: faceVerified),
                destination: const Scaffold(
                  key: _formKey,
                  body: Text('Application form'),
                ),
                actionName: 'apply as a blood donor',
              ),
              child: const Text('Resubmit application'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Resubmit application'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('verified user with an ID on file goes straight to the form', (
    tester,
  ) async {
    await _tapEntry(
      tester,
      faceVerified: true,
      idStatus: IdVerificationStatus.submitted,
    );
    expect(find.byKey(_formKey), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('face not verified: told before the form, form not opened', (
    tester,
  ) async {
    await _tapEntry(
      tester,
      faceVerified: false,
      idStatus: IdVerificationStatus.submitted,
    );
    expect(find.byKey(_formKey), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Face Not Verified'), findsOneWidget);
    expect(find.text('Verify My Face'), findsOneWidget);
  });

  testWidgets('no ID and no face check: asked to upload an ID first', (
    tester,
  ) async {
    await _tapEntry(tester, faceVerified: false, idStatus: null);
    expect(find.byKey(_formKey), findsNothing);
    expect(find.text('Not Verified'), findsOneWidget);
    expect(find.text('Upload Valid ID'), findsOneWidget);
  });

  testWidgets('face verified but no ID on file: ID required, form not opened', (
    tester,
  ) async {
    await _tapEntry(tester, faceVerified: true, idStatus: null);
    expect(find.byKey(_formKey), findsNothing);
    expect(find.text('ID Submission Required'), findsOneWidget);
    expect(find.text('Submit Valid ID'), findsOneWidget);
  });

  testWidgets('Cancel closes the dialog and stays put', (tester) async {
    await _tapEntry(tester, faceVerified: true, idStatus: null);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(_formKey), findsNothing);
    expect(find.text('Resubmit application'), findsOneWidget);
  });
}
