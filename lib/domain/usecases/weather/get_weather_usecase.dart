import '../../models/weather_forecast.dart';
import '../../repositories/i_weather_repository.dart';

class GetWeatherUseCase {
  final IWeatherRepository repository;

  GetWeatherUseCase(this.repository);

  Future<WeatherForecast> execute({
    required double latitude,
    required double longitude,
  }) {
    return repository.getWeatherForecast(
      latitude: latitude,
      longitude: longitude,
    );
  }
}
