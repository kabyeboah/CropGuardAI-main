/// Agricultural seasonal disease risk calculator for Ghanaian rainfall patterns.
class GhanaSeasonalTip {
  static bool isHighRisk() {
    final month = DateTime.now().month;
    return (month >= 3 && month <= 6) || (month >= 9 && month <= 11);
  }

  static String getAlertMessage() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 6) {
      return '⚠️ Major rainy season: high risk of fungal diseases. Inspect crops frequently.';
    }
    if (month >= 9 && month <= 11) {
      return '⚠️ Minor rainy season: watch for blight and mildew. Ensure good field drainage.';
    }
    return '';
  }

  static int getDailyTipIndex(int total) {
    final dayOfYear = DateTime.now()
        .difference(
          DateTime(DateTime.now().year, 1, 1),
        )
        .inDays;
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
