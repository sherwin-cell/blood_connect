import 'dart:convert';
import 'dart:io';

import 'package:blood_connect/core/services/secure_upload_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late File pdf;

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('secure_upload_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    pdf = File('${dir.path}/form.pdf')
      ..writeAsBytesSync(utf8.encode('%PDF-1.4'));
  });

  SecureUploadApi api(
    MockClient client, {
    String baseUrl = 'http://api.test',
  }) => SecureUploadApi(
    client: client,
    idToken: () async => 'token-1',
    baseUrl: baseUrl,
  );

  test(
    'uploads to /api/files/<kind> with the ID token and returns the ref',
    () async {
      late http.BaseRequest seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'code': 'uploaded',
            'ref': 'secure://raw/f/u1/brf/a.pdf',
          }),
          200,
        );
      });

      final ref = await api(
        client,
      ).upload(pdf, SecureUploadKind.bloodRequestForm);

      expect(ref, 'secure://raw/f/u1/brf/a.pdf');
      expect(seen.url.toString(), 'http://api.test/api/files/brf');
      expect(seen.headers['Authorization'], 'Bearer token-1');
    },
  );

  test('surfaces the backend message on failure', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'code': 'invalid_file_type',
          'message': 'The file must be a PDF.',
        }),
        400,
      ),
    );

    expect(
      () => api(client).upload(pdf, SecureUploadKind.bloodRequestForm),
      throwsA(
        isA<SecureUploadException>()
            .having((e) => e.message, 'message', 'The file must be a PDF.')
            .having((e) => e.statusCode, 'statusCode', 400),
      ),
    );
  });

  test('rejects a success response without a secure:// ref', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'ref': 'https://public.example/x.pdf'}),
        200,
      ),
    );

    expect(
      () => api(client).upload(pdf, SecureUploadKind.bloodRequestForm),
      throwsA(isA<SecureUploadException>()),
    );
  });

  test('explains a build without API_BASE_URL', () async {
    final client = MockClient((_) async => fail('must not call the network'));

    expect(
      () => api(client, baseUrl: '').upload(pdf, SecureUploadKind.idFront),
      throwsA(
        isA<SecureUploadException>().having(
          (e) => e.message,
          'message',
          contains('API_BASE_URL'),
        ),
      ),
    );
  });
}
