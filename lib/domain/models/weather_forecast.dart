class WeatherForecast {
  final double latitude;
  final double longitude;
  final List<DailyForecast> daily;

  WeatherForecast({
    required this.latitude,
    required this.longitude,
    required this.daily,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'daily': {
          'time': daily
              .map((d) => d.date.toIso8601String().substring(0, 10))
              .toList(),
          'temperature_2m_max': daily.map((d) => d.maxTemp).toList(),
          'temperature_2m_min': daily.map((d) => d.minTemp).toList(),
          'precipitation_probability_max':
              daily.map((d) => d.precipitationProbability).toList(),
          'relative_humidity_2m_max': daily.map((d) => d.humidity).toList(),
          'weather_code': daily.map((d) => d.weatherCode).toList(),
        },
      };

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final dailyJson = json['daily'];
    final List<String> times = List<String>.from(dailyJson['time']);
    // Open-Meteo may return integers for whole-number values (e.g. 25 instead
    // of 25.0). Cast via num.toDouble() to avoid "type 'int' is not a subtype
    // of type 'double'" at runtime.
    final List<double> maxTemps =
        List<num>.from(dailyJson['temperature_2m_max'])
            .map((e) => e.toDouble())
            .toList();
    final List<double> minTemps =
        List<num>.from(dailyJson['temperature_2m_min'])
            .map((e) => e.toDouble())
            .toList();
    final List<double> rainProb =
        List<num>.from(dailyJson['precipitation_probability_max'])
            .map((e) => e.toDouble())
            .toList();
    final List<double> humidity = dailyJson['relative_humidity_2m_max'] != null
        ? List<num>.from(dailyJson['relative_humidity_2m_max'])
            .map((e) => e.toDouble())
            .toList()
        : <double>[];
    final List<int> weatherCodes = List<int>.from(dailyJson['weather_code']);

    final List<DailyForecast> dailyList = [];
    for (int i = 0; i < times.length; i++) {
      dailyList.add(DailyForecast(
        date: DateTime.parse(times[i]),
        maxTemp: maxTemps[i],
        minTemp: minTemps[i],
        precipitationProbability: rainProb[i],
        humidity: humidity.isNotEmpty ? humidity[i] : 0.0,
        weatherCode: weatherCodes[i],
      ));
    }

    return WeatherForecast(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      daily: dailyList,
    );
  }
}

class DailyForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final double precipitationProbability;
  final double humidity;
  final int weatherCode;

  DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.precipitationProbability,
    required this.humidity,
    required this.weatherCode,
  });

  String get weatherIcon {
    // WMO Weather interpretation codes (WW)
    // https://open-meteo.com/en/docs
    if (weatherCode == 0) {
      return '☀️'; // Clear sky
    }
    if (weatherCode <= 3) {
      return '⛅'; // Mainly clear, partly cloudy, and overcast
    }
    if (weatherCode <= 48) {
      return '🌫️'; // Fog
    }
    if (weatherCode <= 55) {
      return '🌦️'; // Drizzle
    }
    if (weatherCode <= 65) {
      return '🌧️'; // Rain
    }
    if (weatherCode <= 77) {
      return '❄️'; // Snow
    }
    if (weatherCode <= 82) {
      return '⛈️'; // Rain showers
    }
    if (weatherCode <= 86) {
      return '🌨️'; // Snow showers
    }
    if (weatherCode <= 99) {
      return '⛈️'; // Thunderstorm
    }
    return '❓';
  }

  String get weatherDescription {
    if (weatherCode == 0) return 'Clear sky';
    if (weatherCode <= 3) return 'Partly cloudy';
    if (weatherCode <= 48) return 'Foggy';
    if (weatherCode <= 55) return 'Drizzle';
    if (weatherCode <= 65) return 'Rainy';
    if (weatherCode <= 82) return 'Rain showers';
    if (weatherCode <= 99) return 'Thunderstorm';
    return 'Unknown';
  }
}
