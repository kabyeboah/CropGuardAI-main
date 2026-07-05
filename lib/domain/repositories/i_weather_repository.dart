import '../models/weather_forecast.dart';

abstract class IWeatherRepository {
  Future<WeatherForecast> getWeatherForecast({
    required double latitude,
    required double longitude,
  });
}
