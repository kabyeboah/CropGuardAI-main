import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cropguard_flutter/core/config/app_secrets.dart';
import 'package:cropguard_flutter/core/utils/nominatim_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://nominatim.openstreetmap.org'));
  });

  late MockHttpClient mockClient;

  setUp(() {
    mockClient = MockHttpClient();
    SharedPreferences.setMockInitialValues({});
    NominatimService.clearCache();
    AppSecrets.reset();
  });

  tearDown(() {
    NominatimService.clearCache();
    AppSecrets.reset();
  });

  test('NominatimService sends compliant User-Agent header', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = NominatimService(httpClient: mockClient, prefs: prefs);

    when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'address': {'city': 'Kumasi', 'country': 'Ghana'}
          }),
          200,
        ));

    final result = await service.reverseGeocode(6.6885, -1.6244);

    expect(result, 'Kumasi');
    final captured = verify(() => mockClient.get(
          captureAny(),
          headers: captureAny(named: 'headers'),
        )).captured;

    final headers = captured[1] as Map<String, String>;
    expect(headers['User-Agent'], isNotEmpty);
    expect(headers['User-Agent'], contains('CropGuardAI'));
    expect(headers['User-Agent'], contains('com.cropguard.ai.app'));
  });

  test(
      'NominatimService caches lookups by coarsened coordinates in memory and prefs',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final service = NominatimService(httpClient: mockClient, prefs: prefs);

    when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'address': {'town': 'Ejisu', 'country': 'Ghana'}
          }),
          200,
        ));

    // First call: makes network request
    final res1 = await service.reverseGeocode(6.68851234, -1.62445678);
    expect(res1, 'Ejisu');
    verify(() => mockClient.get(any(), headers: any(named: 'headers')))
        .called(1);

    // Second call with slightly different coordinate within same ~1km bucket (6.69, -1.62):
    final res2 = await service.reverseGeocode(6.6891234, -1.6241111);
    expect(res2, 'Ejisu');
    // Verifies NO second network request is made
    verifyNever(() => mockClient.get(any(), headers: any(named: 'headers')));
  });

  test(
      'NominatimService recovers from persistent cache across service instances',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final service1 = NominatimService(httpClient: mockClient, prefs: prefs);

    when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'address': {'village': 'Abetifi', 'country': 'Ghana'}
          }),
          200,
        ));

    await service1.reverseGeocode(6.6712, -0.7489);
    verify(() => mockClient.get(any(), headers: any(named: 'headers')))
        .called(1);

    // Clear memory cache to simulate app restart with same SharedPreferences
    NominatimService.clearCache();

    final service2 = NominatimService(httpClient: mockClient, prefs: prefs);
    final res = await service2.reverseGeocode(6.6712, -0.7489);

    expect(res, 'Abetifi');
    // Persistent cache hit — no network call
    verifyNever(() => mockClient.get(any(), headers: any(named: 'headers')));
  });

  test(
      'NominatimService throttles network requests to satisfy 1 req/sec policy',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final service = NominatimService(httpClient: mockClient, prefs: prefs);

    when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => http.Response(
          jsonEncode({
            'address': {'county': 'Sunyani District', 'country': 'Ghana'}
          }),
          200,
        ));

    final stopwatch = Stopwatch()..start();
    // Two distinct coordinate buckets far apart to bypass coordinate caching
    await service.reverseGeocode(7.34, -2.32);
    await service.reverseGeocode(9.40, -0.83);
    stopwatch.stop();

    // Must have waited at least ~1000ms between calls
    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(950));
    verify(() => mockClient.get(any(), headers: any(named: 'headers')))
        .called(2);
  });

  test(
      'NominatimService falls back to regional centroid on HTTP error or timeout',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final service = NominatimService(httpClient: mockClient, prefs: prefs);

    when(() => mockClient.get(
          any(),
          headers: any(named: 'headers'),
        )).thenAnswer((_) async => http.Response('Internal Server Error', 500));

    final result = await service.reverseGeocode(6.6885, -1.6244);
    // Falls back to Ghana region (Ashanti for Kumasi coordinates)
    expect(result, 'Ashanti');
  });
}
