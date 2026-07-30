import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Equivalent of GhanaSeasonalTip.kt
class GhanaSeasonalTip {
  static bool isHighRisk() {
    final month = DateTime.now().month;
    try {
      final config = FirebaseRemoteConfig.instance;
      final majorStart = config.getInt('rainy_major_start');
      final majorEnd = config.getInt('rainy_major_end');
      final minorStart = config.getInt('rainy_minor_start');
      final minorEnd = config.getInt('rainy_minor_end');

      // Default to hardcoded values if config is not set (0)
      if (majorStart == 0) {
        return (month >= 3 && month <= 6) || (month >= 9 && month <= 11);
      }

      return (month >= majorStart && month <= majorEnd) ||
          (month >= minorStart && month <= minorEnd);
    } catch (_) {
      return (month >= 3 && month <= 6) || (month >= 9 && month <= 11);
    }
  }

  static String getAlertMessage() {
    final month = DateTime.now().month;
    try {
      final config = FirebaseRemoteConfig.instance;
      final majorMsg = config.getString('rainy_major_msg');
      final minorMsg = config.getString('rainy_minor_msg');

      // Use the same Remote Config ranges as isHighRisk() so the two methods
      // stay consistent. Fall back to hardcoded ranges when config is not set.
      final rawMajorStart = config.getInt('rainy_major_start');
      final rawMajorEnd   = config.getInt('rainy_major_end');
      final rawMinorStart = config.getInt('rainy_minor_start');
      final rawMinorEnd   = config.getInt('rainy_minor_end');
      final majorStart = rawMajorStart > 0 ? rawMajorStart : 3;
      final majorEnd   = rawMajorEnd   > 0 ? rawMajorEnd   : 6;
      final minorStart = rawMinorStart > 0 ? rawMinorStart : 9;
      final minorEnd   = rawMinorEnd   > 0 ? rawMinorEnd   : 11;

      if (month >= majorStart && month <= majorEnd) {
        return majorMsg.isNotEmpty
            ? majorMsg
            : '⚠️ Major rainy season: high risk of fungal diseases. Inspect crops frequently.';
      }
      if (month >= minorStart && month <= minorEnd) {
        return minorMsg.isNotEmpty
            ? minorMsg
            : '⚠️ Minor rainy season: watch for blight and mildew. Ensure good field drainage.';
      }
      return '';
    } catch (_) {
      if (month >= 3 && month <= 6) {
        return '⚠️ Major rainy season: high risk of fungal diseases. Inspect crops frequently.';
      }
      if (month >= 9 && month <= 11) {
        return '⚠️ Minor rainy season: watch for blight and mildew. Ensure good field drainage.';
      }
      return '';
    }
  }

  static int getDailyTipIndex(int total) {
    final dayOfYear = DateTime.now().difference(
          DateTime(DateTime.now().year, 1, 1),
        ).inDays;
    return dayOfYear % total;
  }
}

const List<String> dailyTips = [
  'Inspect your crops early in the morning for signs of disease.',
  'Ensure proper spacing between plants for good air circulation.',
  'Rotate crops each season to reduce disease buildup in soil.',
  'Remove and dispose of infected plant material immediately.',
  'Apply fungicides preventively during rainy seasons.',
  'Keep field tools clean to avoid spreading pathogens.',
  'Monitor weather forecasts — humidity accelerates disease spread.',
  'Use certified disease-resistant seed varieties where possible.',
];
