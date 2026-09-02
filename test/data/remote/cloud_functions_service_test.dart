import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/data/remote/cloud_functions_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient mockHttpClient;
  String? currentToken;
  late CloudFunctionsService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    currentToken = 'fake-jwt-token-123';

    service = CloudFunctionsService(
      client: mockHttpClient,
      authTokenProvider: () async => currentToken,
      region: 'us-central1',
      projectId: 'test-project',
    );
  });

  group('CloudFunctionsService', () {
    test('verifyOutbreak throws AuthFailure when user is not signed in',
        () async {
      currentToken = null;

      expect(
        () => service.verifyOutbreak(reportId: 'rep_123', confirm: true),
        throwsA(isA<AuthFailure>()),
      );
    });

    test(
        'verifyOutbreak sends authenticated request and parses success response',
        () async {
      currentToken = 'fake-jwt-token-123';

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'result': {
                'success': true,
                'status': 'updated',
                'confidenceScore': 3,
              }
            }),
            200,
          ));

      final result =
          await service.verifyOutbreak(reportId: 'rep_123', confirm: true);
      expect(result['status'], 'updated');
      expect(result['confidenceScore'], 3);

      verify(() => mockHttpClient.post(
            Uri.parse(
                'https://us-central1-test-project.cloudfunctions.net/verifyOutbreak'),
            headers: any(
              named: 'headers',
              that: containsPair('Authorization', 'Bearer fake-jwt-token-123'),
            ),
            body: jsonEncode({
              'data': {
                'reportId': 'rep_123',
                'confirm': true,
              }
            }),
          )).called(1);
    });

    test('verifyOutbreak throws AuthFailure on 401 response', () async {
      currentToken = 'fake-jwt-token-123';

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Unauthorized', 401));

      expect(
        () => service.verifyOutbreak(reportId: 'rep_123', confirm: true),
        throwsA(isA<AuthFailure>()),
      );
    });

    test(
        'analyzeCropWithGemini proxies request with auth token and returns analysis result',
        () async {
      currentToken = 'fake-jwt-token-123';

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'result': {
                'label': 'Cocoa Black Pod Disease',
                'confidence': 0.95,
                'isHealthy': false,
                'symptoms': ['Blackened pod lesions'],
                'rootCause': 'Phytophthora palmivora',
                'organicRemedies': ['Copper fungicide spray'],
                'preventionTips': ['Improve shade management'],
                'rawReasoning': 'Characteristic black lesions on pod surface.',
              }
            }),
            200,
          ));

      final result = await service.analyzeCropWithGemini(
        imageBase64: 'fake-base64-image-bytes',
        cropType: 'Cocoa',
        initialTopCandidates: ['Cocoa Black Pod'],
      );

      expect(result['label'], 'Cocoa Black Pod Disease');
      expect(result['confidence'], 0.95);
      expect(result['isHealthy'], isFalse);

      verify(() => mockHttpClient.post(
            Uri.parse(
                'https://us-central1-test-project.cloudfunctions.net/analyzeCropWithGemini'),
            headers: any(
              named: 'headers',
              that: containsPair('Authorization', 'Bearer fake-jwt-token-123'),
            ),
            body: any(named: 'body'),
          )).called(1);
    });

    test(
        'synthesizeGhanaNlp proxies TTS request and returns decoded audio bytes',
        () async {
      currentToken = 'fake-jwt-token-123';

      final fakeAudioBytes = utf8.encode('RIFF-WAVE-AUDIO-DATA');
      final fakeBase64 = base64Encode(fakeAudioBytes);

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'result': {
                'success': true,
                'audioBase64': fakeBase64,
                'language': 'tw',
              }
            }),
            200,
          ));

      final audioBytes = await service.synthesizeGhanaNlp(
        text: 'Medaase',
        language: 'tw',
      );

      expect(audioBytes, fakeAudioBytes);
    });

    test('transcribeGhanaNlp proxies ASR audio and returns transcribed text',
        () async {
      currentToken = 'fake-jwt-token-123';

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'result': {
                'success': true,
                'transcription': 'Kookoo yareɛ',
                'language': 'tw',
              }
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      final text = await service.transcribeGhanaNlp(
        audioBytes: utf8.encode('audio-raw-bytes'),
        language: 'tw',
      );

      expect(text, 'Kookoo yareɛ');
    });

    test('translateGhanaNlp proxies translation text and returns translated string',
        () async {
      currentToken = 'fake-jwt-token-123';

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
            jsonEncode({
              'result': {
                'success': true,
                'translation': 'Mema wo akye',
                'languagePair': 'en-tw',
              }
            }),
            200,
          ));

      final text = await service.translateGhanaNlp(
        text: 'Good morning',
        languagePair: 'en-tw',
      );

      expect(text, 'Mema wo akye');
    });

    test('default constructed service uses real project id (cropguard-6ada8)',
        () async {
      final defaultClient = MockHttpClient();
      final defaultService = CloudFunctionsService(
        client: defaultClient,
        authTokenProvider: () async => 'token',
      );

      when(() => defaultClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((invocation) async {
        final uri = invocation.positionalArguments[0] as Uri;
        expect(uri.host, 'us-central1-cropguard-6ada8.cloudfunctions.net');
        return http.Response(
          jsonEncode({
            'result': {
              'success': true,
              'status': 'updated',
              'confidenceScore': 3,
            }
          }),
          200,
        );
      });

      final res = await defaultService.verifyOutbreak(
        reportId: 'rep_123',
        confirm: true,
      );
      expect(res['success'], isTrue);
    });
  });
}
