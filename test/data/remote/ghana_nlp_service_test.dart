import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/config/khaya_language_config.dart';
import 'package:cropguard_flutter/data/remote/cloud_functions_service.dart';
import 'package:cropguard_flutter/data/remote/ghana_nlp_service.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockCloudFunctionsService extends Mock implements CloudFunctionsService {}

// ── Helpers ────────────────────────────────────────────────────────────────

Uint8List _minimalWavBytes() {
  final data = ByteData(44);
  data.setUint32(0, 0x52494646, Endian.big);
  data.setUint32(4, 36, Endian.little);
  data.setUint32(8, 0x57415645, Endian.big);
  data.setUint32(12, 0x666d7420, Endian.big);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  data.setUint32(36, 0x64617461, Endian.big);
  data.setUint32(40, 0, Endian.little);
  return data.buffer.asUint8List();
}

void _stubPathProvider(String dirPath) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall call) async {
      if (call.method == 'getTemporaryDirectory') {
        return dirPath;
      }
      return null;
    },
  );
}

void _clearPathProviderStub() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    null,
  );
}

/// Creates a fresh GhanaNlpService backed by [mock] for each test.
/// Works around the singleton by injecting the mock each time.
GhanaNlpService _serviceWith(MockCloudFunctionsService mock) {
  return GhanaNlpService(functions: mock);
}

// ══════════════════════════════════════════════════════════════════════════════
// API VERSION REGRESSION TESTS
// CRITICAL: These tests MUST fail if deprecated endpoint versions are used.
// ══════════════════════════════════════════════════════════════════════════════

void _apiVersionTests() {
  group('API Version Regression', () {
    test('ASR version is v3 (v1 and v2 are deprecated)', () {
      expect(KhayaApiVersions.asrVersion, 'v3');
    });

    test('TTS version is v2 (v1 is deprecated)', () {
      expect(KhayaApiVersions.ttsVersion, 'v2');
    });

    test('Translation version is v2 (v1 is deprecated)', () {
      expect(KhayaApiVersions.translationVersion, 'v2');
    });

    test('KhayaApiConfig versions are consistent with KhayaApiVersions', () {
      expect(KhayaApiConfig.asrVersion, KhayaApiVersions.asrVersion);
      expect(KhayaApiConfig.ttsVersion, KhayaApiVersions.ttsVersion);
      expect(KhayaApiConfig.translationVersion, KhayaApiVersions.translationVersion);
    });

    test('ASR version is not deprecated v1 or v2', () {
      expect(KhayaApiVersions.asrVersion, isNot('v1'));
      expect(KhayaApiVersions.asrVersion, isNot('v2'));
    });

    test('TTS version is not deprecated v1', () {
      expect(KhayaApiVersions.ttsVersion, isNot('v1'));
    });

    test('Translation version is not deprecated v1', () {
      expect(KhayaApiVersions.translationVersion, isNot('v1'));
    });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// LANGUAGE REGISTRY TESTS
// ══════════════════════════════════════════════════════════════════════════════

void _registryTests() {
  group('KhayaLanguageRegistry', () {
    test('Twi is registered and fully supported', () {
      final c = KhayaLanguageRegistry.byLocale('tw')!;
      expect(c.providerCode, 'tw');
      expect(c.asrSupported, isTrue);
      expect(c.ttsSupported, isTrue);
      expect(c.translationSupported, isTrue);
      expect(c.ttsSpeakerId, 'twi_speaker_4');
    });

    test('Ewe is registered and fully supported', () {
      final c = KhayaLanguageRegistry.byLocale('ee')!;
      expect(c.ttsSpeakerId, 'ewe_speaker_1');
      expect(c.asrSupported, isTrue);
    });

    test('Dagbani is registered and fully supported', () {
      final c = KhayaLanguageRegistry.byLocale('dag')!;
      expect(c.ttsSpeakerId, 'dagbani_speaker_1');
      expect(c.asrSupported, isTrue);
    });

    test('Twi language pair strings are correct', () {
      final c = KhayaLanguageRegistry.byLocale('tw')!;
      expect(c.toEnglishPair, 'tw-en');
      expect(c.fromEnglishPair, 'en-tw');
    });

    test('asrSupported list includes Twi, Ewe, Dagbani', () {
      final codes = KhayaLanguageRegistry.asrSupported.map((l) => l.providerCode);
      expect(codes, containsAll(['tw', 'ee', 'dag']));
    });

    test('unknown locale returns null', () {
      expect(KhayaLanguageRegistry.byLocale('zz'), isNull);
    });

    test('supportsAsr returns false for unknown locale', () {
      expect(KhayaLanguageRegistry.supportsAsr('zz'), isFalse);
    });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// TTS TESTS
// ══════════════════════════════════════════════════════════════════════════════

void _ttsTests() {
  late MockCloudFunctionsService mockFunctions;
  late Directory tempTtsDir;

  setUp(() async {
    mockFunctions = MockCloudFunctionsService();
    tempTtsDir = await Directory.systemTemp.createTemp('cg_tts_test_');
    _stubPathProvider(tempTtsDir.path);
  });

  tearDown(() async {
    _clearPathProviderStub();
    if (await tempTtsDir.exists()) {
      await tempTtsDir.delete(recursive: true);
    }
  });

  group('GhanaNlpService.synthesize (TTS v2)', () {
    test('success: returns a File', () async {
      final fakeAudio = Uint8List.fromList([0x52, 0x49, 0x46, 0x46]);
      when(() => mockFunctions.synthesizeGhanaNlp(
            text: any(named: 'text'),
            language: any(named: 'language'),
          )).thenAnswer((_) async => fakeAudio);

      final service = _serviceWith(mockFunctions);
      final result = await service.synthesize('Mema wo akye', language: 'tw');

      expect(result, isNotNull);
      expect(result!.existsSync(), isTrue);
      result.deleteSync();
    });

    test('caches result — backend called only once for identical text+language',
        () async {
      final fakeAudio = Uint8List.fromList([0x52, 0x49, 0x46, 0x46]);
      when(() => mockFunctions.synthesizeGhanaNlp(
            text: any(named: 'text'),
            language: any(named: 'language'),
          )).thenAnswer((_) async => fakeAudio);

      final service = _serviceWith(mockFunctions);
      final a = await service.synthesize('cache_test_unique', language: 'tw');
      final b = await service.synthesize('cache_test_unique', language: 'tw');

      expect(a!.path, equals(b!.path));
      verify(() => mockFunctions.synthesizeGhanaNlp(
            text: any(named: 'text'),
            language: any(named: 'language'),
          )).called(1);
      a.deleteSync();
    });

    test('empty text: returns null without calling backend', () async {
      final service = _serviceWith(mockFunctions);
      final result = await service.synthesize('', language: 'tw');
      expect(result, isNull);
      verifyNever(() => mockFunctions.synthesizeGhanaNlp(
            text: any(named: 'text'),
            language: any(named: 'language'),
          ));
    });

    test('backend returns empty bytes: returns null', () async {
      when(() => mockFunctions.synthesizeGhanaNlp(
            text: any(named: 'text'),
            language: any(named: 'language'),
          )).thenAnswer((_) async => Uint8List(0));

      final service = _serviceWith(mockFunctions);
      final result = await service.synthesize('empty_audio_test', language: 'tw');
      expect(result, isNull);
    });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// ASR TESTS
// ══════════════════════════════════════════════════════════════════════════════

void _asrTests() {
  late MockCloudFunctionsService mockFunctions;
  late File tempAudio;

  setUp(() async {
    mockFunctions = MockCloudFunctionsService();
    tempAudio = File(
        '${Directory.systemTemp.path}/cg_asr_${DateTime.now().microsecondsSinceEpoch}.wav');
    await tempAudio.writeAsBytes(_minimalWavBytes());
  });

  tearDown(() async {
    if (await tempAudio.exists()) await tempAudio.delete();
  });

  group('GhanaNlpService.transcribe (ASR v3)', () {
    test('success: backend proxy returns transcript', () async {
      when(() => mockFunctions.transcribeGhanaNlp(
            audioBytes: any(named: 'audioBytes'),
            language: any(named: 'language'),
          )).thenAnswer((_) async => 'Mema wo akye');

      final service = _serviceWith(mockFunctions);
      final result = await service.transcribe(tempAudio, language: 'tw');
      expect(result, 'Mema wo akye');
    });

    test('empty transcript from backend: returns null', () async {
      when(() => mockFunctions.transcribeGhanaNlp(
            audioBytes: any(named: 'audioBytes'),
            language: any(named: 'language'),
          )).thenAnswer((_) async => '');

      final service = _serviceWith(mockFunctions);
      final result = await service.transcribe(tempAudio, language: 'tw');
      expect(result, isNull);
    });

    test('non-existent file: returns null without calling backend',
        () async {
      final service = _serviceWith(mockFunctions);
      final result = await service.transcribe(
          File('/tmp/__cg_no_file__.wav'), language: 'tw');
      expect(result, isNull);
      verifyNever(() => mockFunctions.transcribeGhanaNlp(
            audioBytes: any(named: 'audioBytes'),
            language: any(named: 'language'),
          ));
    });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// TRANSLATION TESTS
// ══════════════════════════════════════════════════════════════════════════════

void _translationTests() {
  late MockCloudFunctionsService mockFunctions;

  setUp(() {
    mockFunctions = MockCloudFunctionsService();
  });

  group('GhanaNlpService.translate (Translation v2)', () {
    test('success: backend proxy returns translated text', () async {
      when(() => mockFunctions.translateGhanaNlp(
            text: any(named: 'text'),
            languagePair: any(named: 'languagePair'),
          )).thenAnswer((_) async => 'Mema wo akye');

      final service = _serviceWith(mockFunctions);
      final result =
          await service.translate('Good morning', languagePair: 'en-tw');
      expect(result, 'Mema wo akye');
    });

    test('same-language pair: skips backend and returns input as-is',
        () async {
      final service = _serviceWith(mockFunctions);
      final result = await service.translate('Hello', languagePair: 'en-en');
      expect(result, 'Hello');
      verifyNever(() => mockFunctions.translateGhanaNlp(
            text: any(named: 'text'),
            languagePair: any(named: 'languagePair'),
          ));
    });

    test('empty input text: returns null immediately', () async {
      final service = _serviceWith(mockFunctions);
      final result = await service.translate('', languagePair: 'en-tw');
      expect(result, isNull);
      verifyNever(() => mockFunctions.translateGhanaNlp(
            text: any(named: 'text'),
            languagePair: any(named: 'languagePair'),
          ));
    });

    test('Twi to English works', () async {
      when(() => mockFunctions.translateGhanaNlp(
            text: any(named: 'text'),
            languagePair: 'tw-en',
          )).thenAnswer((_) async => 'Good morning');

      final service = _serviceWith(mockFunctions);
      final result =
          await service.translate('Mema wo akye', languagePair: 'tw-en');
      expect(result, 'Good morning');
    });
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════════════

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  _apiVersionTests();
  _registryTests();
  _ttsTests();
  _asrTests();
  _translationTests();
}
