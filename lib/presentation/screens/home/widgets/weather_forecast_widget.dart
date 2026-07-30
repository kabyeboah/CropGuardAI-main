import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/weather_forecast.dart';
import '../../../../core/utils/locale_formatter.dart';

class WeatherForecastWidget extends StatelessWidget {
  final WeatherForecast weather;
  final String locationName;

  const WeatherForecastWidget({
    super.key,
    required this.weather,
    this.locationName = 'Ghana',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.l10n.sevenDayForecast, 
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: colors.muted),
                const SizedBox(width: 2),
                Text(locationName,
                    style: TextStyle(color: colors.muted, fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: weather.daily.length,
            itemBuilder: (context, index) {
              final day = weather.daily[index];
              final isToday = index == 0;
              
              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isToday ? colors.primary.withValues(alpha: 0.1) : colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isToday ? colors.primary : colors.border,
                    width: isToday ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isToday ? context.l10n.today : LocaleFormatter.formatDayOfWeek(context, day.date),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? colors.primary : colors.onBackgroundSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(day.weatherIcon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      '${day.maxTemp.toInt()}°',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${day.precipitationProbability.toInt()}% rain',
                      style: TextStyle(fontSize: 9, color: colors.muted),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
