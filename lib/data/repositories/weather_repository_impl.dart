import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/models/weather_forecast.dart';
import '../../domain/repositories/i_weather_repository.dart';

class WeatherRepositoryImpl implements IWeatherRepository {
  final http.Client client;

  WeatherRepositoryImpl({http.Client? client}) : client = client ?? http.Client();

  @override
  Future<WeatherForecast> getWeatherForecast({
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?'
      'latitude=$latitude&longitude=$longitude'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,relative_humidity_2m_max'
      '&timezone=auto',
    );

    try {
      final response =
          await client.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherForecast.fromJson(data);
      } else {
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching weather: $e');
    }
  }
}
