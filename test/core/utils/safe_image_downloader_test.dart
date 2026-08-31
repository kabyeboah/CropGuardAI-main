import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/core/utils/safe_image_downloader.dart';

// Helper to generate minimal valid JPEG magic bytes
Uint8List createValidJpegBytes() {
  return Uint8List.fromList([
    0xFF,
    0xD8,
    0xFF,
    0xE0,
    0x00,
    0x10,
    0x4A,
    0x46,
    0x49,
    0x46,
    0x00,
    0x01,
    0x01,
    0x00,
    0x00,
    0x01,
  ]);
}

// Helper to generate minimal valid PNG magic bytes
Uint8List createValidPngBytes() {
  return Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('SafeImageDownloader - IP Security & SSRF Rules', () {
    test('blocks loopback IPv4 addresses (127.0.0.1, 127.0.1.1)', () {
      final addr1 = InternetAddress('127.0.0.1');
      final addr2 = InternetAddress('127.255.255.254');
      expect(SafeImageDownloader.isPrivateOrRestrictedAddress(addr1), isTrue);
      expect(SafeImageDownloader.isPrivateOrRestrictedAddress(addr2), isTrue);
    });

    test('blocks private IPv4 Class A (10.0.0.0/8)', () {
      final addr = InternetAddress('10.15.20.1');
      expect(SafeImageDownloader.isPrivateOrRestrictedAddress(addr), isTrue);
    });

    test('blocks private IPv4 Class B (172.16.0.0/12)', () {
      final addr1 = InternetAddress('172.16.0.1');
      final addr2 = InternetAddress('172.31.255.254');
      expect(SafeImageDownloader.isPrivateOrRestrictedAddress(addr1), isTrue);
      expect(SafeImageDownloader.isPrivateOrRestrictedAddress(addr2), isTrue);
    });

    test('blocks private IPv4 Class C (192.168.0.0/16)', () {
      final addr = InternetAddress('192.168.1.100');
      expect(SafeImageDownloader.isPrivateOrRestrictedAddress(addr), isTrue);
    });

    test(
        'blocks link-local IPv4 (169.254.0.0/16, e.g. AWS/GCP metadata 169.254.169.254)',
        () {
      final addr = InternetAddress('169.254.169.254');
      expect(SafeImageDownloader.isPrivateOrRestrictedAddress(addr), isTrue);
    });

    test('blocks Carrier-Grade NAT (100.64.0.0/10)', () {
      final addr = InternetAddress('100.64.10.5');
      expect(SafeImageDownloader.isPrivateOrRestrictedAddress(addr), isTrue);
    });

    test(
        'blocks documentation and benchmark test nets (192.0.2.1, 198.51.100.1, 203.0.113.1, 198.18.1.1)',
        () {
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('192.0.2.1')),
          isTrue);
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('198.51.100.1')),
          isTrue);
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('203.0.113.1')),
          isTrue);
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('198.18.1.1')),
          isTrue);
    });

    test('blocks multicast and reserved/future IPv4 (224.0.0.1, 240.0.0.1)',
        () {
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('224.0.0.1')),
          isTrue);
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('240.0.0.1')),
          isTrue);
    });

    test('blocks IPv6 loopback, ULA, and link-local (::1, fc00::1, fe80::1)',
        () {
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('::1')),
          isTrue);
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('fc00::1')),
          isTrue);
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('fd12:3456:789a::1')),
          isTrue);
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('fe80::1')),
          isTrue);
    });

    test('allows legitimate public IPv4 and IPv6 addresses', () {
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('8.8.8.8')),
          isFalse);
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('1.1.1.1')),
          isFalse);
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('142.250.180.206')),
          isFalse);
      expect(
          SafeImageDownloader.isPrivateOrRestrictedAddress(
              InternetAddress('2606:4700:4700::1111')),
          isFalse);
    });
  });

  group('SafeImageDownloader - Scheme & Destination Validation', () {
    final downloader = SafeImageDownloader(
      addressLookup: (host) async => [InternetAddress('8.8.8.8')],
    );

    test('rejects unsafe schemes (file://, data:, ftp://, javascript:)',
        () async {
      expect(
        () => downloader.downloadImage('file:///etc/passwd'),
        throwsA(isA<ImageSecurityException>()),
      );
      expect(
        () => downloader.downloadImage('data:image/png;base64,iVBORw0KGgo='),
        throwsA(isA<ImageSecurityException>()),
      );
      expect(
        () => downloader.downloadImage('ftp://ftp.example.com/image.jpg'),
        throwsA(isA<ImageSecurityException>()),
      );
      expect(
        () => downloader.downloadImage('javascript:alert(1)'),
        throwsA(isA<ImageSecurityException>()),
      );
    });

    test('rejects localhost and loopback domains', () async {
      expect(
        () => downloader.downloadImage('http://localhost/leaf.jpg'),
        throwsA(isA<ImageSecurityException>()),
      );
      expect(
        () => downloader.downloadImage('http://127.0.0.1:8080/test.png'),
        throwsA(isA<ImageSecurityException>()),
      );
      expect(
        () => downloader.downloadImage('http://myhost.localhost/img.jpg'),
        throwsA(isA<ImageSecurityException>()),
      );
      expect(
        () => downloader.downloadImage(
            'http://metadata.google.internal/computeMetadata/v1/'),
        throwsA(isA<ImageSecurityException>()),
      );
    });

    test('rejects domains resolving to private IP addresses (SSRF guard)',
        () async {
      final ssrfDownloader = SafeImageDownloader(
        addressLookup: (host) async => [InternetAddress('192.168.1.50')],
      );

      expect(
        () => ssrfDownloader
            .downloadImage('https://internal-service.example.org/photo.jpg'),
        throwsA(isA<ImageSecurityException>()),
      );
    });
  });

  group('SafeImageDownloader - HTTP Response & Payload Defense', () {
    late _MockHttpClient mockClient;
    late _MockHttpClientRequest mockRequest;
    late _MockHttpHeaders mockRequestHeaders;
    late _MockHttpHeaders mockResponseHeaders;

    setUp(() {
      mockClient = _MockHttpClient();
      mockRequest = _MockHttpClientRequest();
      mockRequestHeaders = _MockHttpHeaders();
      mockResponseHeaders = _MockHttpHeaders();

      when(() => mockClient.getUrl(any())).thenAnswer((_) async => mockRequest);
      when(() => mockRequest.headers).thenReturn(mockRequestHeaders);
    });

    test('successfully downloads and verifies JPEG image', () async {
      final expectedBytes = createValidJpegBytes();
      when(() => mockResponseHeaders.contentType)
          .thenReturn(ContentType('image', 'jpeg'));
      when(() => mockResponseHeaders.value(any())).thenReturn(null);

      final fakeResponse = _FakeHttpClientResponse(
        [expectedBytes],
        headers: mockResponseHeaders,
      );
      when(() => mockRequest.close()).thenAnswer((_) async => fakeResponse);

      final customDownloader = SafeImageDownloader(
        addressLookup: (_) async => [InternetAddress('8.8.8.8')],
        httpClient: mockClient,
      );

      final file = await customDownloader
          .downloadImage('https://safe.example.com/image.jpg');
      expect(await file.exists(), isTrue);
      expect(file.path.endsWith('.jpg'), isTrue);
      expect(await file.readAsBytes(), expectedBytes);
      await file.delete();
    });

    test('successfully downloads and verifies PNG image', () async {
      final expectedBytes = createValidPngBytes();
      when(() => mockResponseHeaders.contentType)
          .thenReturn(ContentType('image', 'png'));
      when(() => mockResponseHeaders.value(any())).thenReturn(null);

      final fakeResponse = _FakeHttpClientResponse(
        [expectedBytes],
        headers: mockResponseHeaders,
      );
      when(() => mockRequest.close()).thenAnswer((_) async => fakeResponse);

      final customDownloader = SafeImageDownloader(
        addressLookup: (_) async => [InternetAddress('8.8.8.8')],
        httpClient: mockClient,
      );

      final file = await customDownloader
          .downloadImage('https://safe.example.com/leaf.png');
      expect(await file.exists(), isTrue);
      expect(file.path.endsWith('.png'), isTrue);
      expect(await file.readAsBytes(), expectedBytes);
      await file.delete();
    });

    test('rejects non-image HTML responses (e.g. 404 or web portal)', () async {
      when(() => mockResponseHeaders.contentType)
          .thenReturn(ContentType('text', 'html'));
      when(() => mockResponseHeaders.value(HttpHeaders.contentTypeHeader))
          .thenReturn('text/html');

      final fakeResponse = _FakeHttpClientResponse(
        [utf8.encode('<html><body>Not Found</body></html>')],
        headers: mockResponseHeaders,
      );
      when(() => mockRequest.close()).thenAnswer((_) async => fakeResponse);

      final customDownloader = SafeImageDownloader(
        addressLookup: (_) async => [InternetAddress('8.8.8.8')],
        httpClient: mockClient,
      );

      expect(
        () => customDownloader
            .downloadImage('https://safe.example.com/not_an_image.html'),
        throwsA(isA<NonImageException>()),
      );
    });

    test(
        'rejects corrupted or non-image magic bytes even with image/jpeg header',
        () async {
      final badBytes = Uint8List.fromList(
          utf8.encode('This is random text, not real JPEG magic bytes'));
      when(() => mockResponseHeaders.contentType)
          .thenReturn(ContentType('image', 'jpeg'));
      when(() => mockResponseHeaders.value(any())).thenReturn(null);

      final fakeResponse = _FakeHttpClientResponse(
        [badBytes],
        headers: mockResponseHeaders,
      );
      when(() => mockRequest.close()).thenAnswer((_) async => fakeResponse);

      final customDownloader = SafeImageDownloader(
        addressLookup: (_) async => [InternetAddress('8.8.8.8')],
        httpClient: mockClient,
      );

      expect(
        () =>
            customDownloader.downloadImage('https://safe.example.com/fake.jpg'),
        throwsA(isA<NonImageException>()),
      );
    });

    test('rejects HTTP 404 / 500 server errors gracefully', () async {
      final fakeResponse = _FakeHttpClientResponse(
        [],
        statusCode: HttpStatus.notFound,
        headers: mockResponseHeaders,
      );
      when(() => mockRequest.close()).thenAnswer((_) async => fakeResponse);

      final customDownloader = SafeImageDownloader(
        addressLookup: (_) async => [InternetAddress('8.8.8.8')],
        httpClient: mockClient,
      );

      expect(
        () => customDownloader
            .downloadImage('https://safe.example.com/missing.jpg'),
        throwsA(predicate(
            (e) => e is ImageNetworkException && e.statusCode == 404)),
      );
    });

    test('rejects oversized responses exceeding 15 MB limit via Content-Length',
        () async {
      final fakeResponse = _FakeHttpClientResponse(
        [],
        contentLength: 20 * 1024 * 1024,
        headers: mockResponseHeaders,
      );
      when(() => mockRequest.close()).thenAnswer((_) async => fakeResponse);

      final customDownloader = SafeImageDownloader(
        addressLookup: (_) async => [InternetAddress('8.8.8.8')],
        httpClient: mockClient,
      );

      expect(
        () =>
            customDownloader.downloadImage('https://safe.example.com/huge.jpg'),
        throwsA(isA<ImageDownloadLimitException>()),
      );
    });

    test('rejects redirect loops exceeding max redirects limit', () async {
      when(() => mockResponseHeaders.value(HttpHeaders.locationHeader))
          .thenReturn('/redirect');
      final fakeResponse = _FakeHttpClientResponse(
        [],
        isRedirect: true,
        statusCode: HttpStatus.movedTemporarily,
        headers: mockResponseHeaders,
      );
      when(() => mockRequest.close()).thenAnswer((_) async => fakeResponse);

      final customDownloader = SafeImageDownloader(
        addressLookup: (_) async => [InternetAddress('8.8.8.8')],
        httpClient: mockClient,
      );

      expect(
        () =>
            customDownloader.downloadImage('https://safe.example.com/redirect'),
        throwsA(isA<ImageSecurityException>()),
      );
    });
  });
}

class _MockHttpClient extends Mock implements HttpClient {}

class _MockHttpClientRequest extends Mock implements HttpClientRequest {}

class _MockHttpHeaders extends Mock implements HttpHeaders {}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final List<List<int>> _data;
  @override
  final int statusCode;
  @override
  final HttpHeaders headers;
  @override
  final int contentLength;
  @override
  final bool isRedirect;

  _FakeHttpClientResponse(
    this._data, {
    this.statusCode = HttpStatus.ok,
    required this.headers,
    this.contentLength = -1,
    this.isRedirect = false,
  });

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.fromIterable(_data).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
