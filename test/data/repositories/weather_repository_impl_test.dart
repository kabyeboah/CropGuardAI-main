import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

import 'package:cropguard_flutter/data/repositories/weather_repository_impl.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockHttpClient mockClient;
  late WeatherRepositoryImpl repository;

  setUp(() {
    mockClient = _MockHttpClient();
    repository = WeatherRepositoryImpl(client: mockClient);
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('WeatherRepositoryImpl - getWeatherForecast', () {
    const double lat = 6.6;
    const double lon = -1.6;

    test('returns WeatherForecast on 200 response with valid JSON', () async {
      const jsonResponse = '''
      {
        "latitude": 6.6,
        "longitude": -1.6,
        "daily": {
          "time": ["2024-06-01"],
          "temperature_2m_max": [31.5],
          "temperature_2m_min": [23.0],
          "precipitation_probability_max": [40.0],
          "relative_humidity_2m_max": [75.0],
          "weather_code": [3]
        }
      }
      ''';

      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response(jsonResponse, 200),
      );

      final forecast = await repository.getWeatherForecast(latitude: lat, longitude: lon);

      expect(forecast.latitude, 6.6);
      expect(forecast.longitude, -1.6);
      expect(forecast.daily, hasLength(1));
      expect(forecast.daily.first.maxTemp, 31.5);
    });

    test('throws exception on non-200 status code', () async {
      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response('Not Found', 404),
      );

      await expectLater(
        () => repository.getWeatherForecast(latitude: lat, longitude: lon),
        throwsException,
      );
    });

    test('throws exception on network exception or timeout', () async {
      when(() => mockClient.get(any())).thenThrow(Exception('Socket closed'));

      await expectLater(
        () => repository.getWeatherForecast(latitude: lat, longitude: lon),
        throwsException,
      );
    });
  });
}
