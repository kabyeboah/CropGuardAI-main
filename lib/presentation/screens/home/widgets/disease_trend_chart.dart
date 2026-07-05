import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class DiseaseTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trend;

  const DiseaseTrendChart({super.key, required this.trend});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (trend.isEmpty) {
      return const SizedBox.shrink();
    }

    final spotsHealthy = <FlSpot>[];
    final spotsDiseased = <FlSpot>[];
    for (var i = 0; i < trend.length; i++) {
      final row = trend[i];
      spotsHealthy.add(FlSpot(
        i.toDouble(),
        (row['healthyCount'] as num?)?.toDouble() ?? 0,
      ));
      spotsDiseased.add(FlSpot(
        i.toDouble(),
        (row['diseasedCount'] as num?)?.toDouble() ?? 0,
      ));
    }

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: colors.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: TextStyle(color: colors.muted, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                  final day = trend[i]['day']?.toString() ?? '';
                  final short = day.length >= 5 ? day.substring(5) : day;
                  return Text(short,
                      style: TextStyle(color: colors.muted, fontSize: 9));
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spotsHealthy,
              isCurved: true,
              color: colors.healthy,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: spotsDiseased,
              isCurved: true,
              color: colors.diseaseRed,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
