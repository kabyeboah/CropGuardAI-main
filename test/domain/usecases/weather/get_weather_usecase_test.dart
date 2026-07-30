import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/domain/models/weather_forecast.dart';
import 'package:cropguard_flutter/domain/repositories/i_weather_repository.dart';
import 'package:cropguard_flutter/domain/usecases/weather/get_weather_usecase.dart';

class _MockWeatherRepo extends Mock implements IWeatherRepository {}

WeatherForecast _makeForecast() => WeatherForecast(
      latitude: 5.56,
      longitude: -0.20,
      daily: [
        DailyForecast(
          date: DateTime(2024, 6, 1),
          maxTemp: 32.0,
          minTemp: 24.0,
          precipitationProbability: 70.0,
          humidity: 85.0,
          weatherCode: 61,
        ),
      ],
    );

void main() {
  late _MockWeatherRepo repo;
  late GetWeatherUseCase useCase;

  setUp(() {
    repo = _MockWeatherRepo();
    useCase = GetWeatherUseCase(repo);
  });

  group('GetWeatherUseCase', () {
    test('delegates to repository with provided coordinates', () async {
      when(() => repo.getWeatherForecast(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => _makeForecast());

      await useCase.execute(latitude: 5.56, longitude: -0.20);

      verify(() => repo.getWeatherForecast(
            latitude: 5.56,
            longitude: -0.20,
          )).called(1);
    });

    test('returns forecast from repository', () async {
      final forecast = _makeForecast();
      when(() => repo.getWeatherForecast(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => forecast);

      final result = await useCase.execute(latitude: 5.56, longitude: -0.20);

      expect(result.latitude, 5.56);
      expect(result.longitude, -0.20);
      expect(result.daily, hasLength(1));
      expect(result.daily.first.maxTemp, 32.0);
    });

    test('propagates exceptions from repository', () async {
      when(() => repo.getWeatherForecast(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => throw Exception('Network timeout'));

      await expectLater(
        () => useCase.execute(latitude: 0, longitude: 0),
        throwsException,
      );
    });
  });
}
