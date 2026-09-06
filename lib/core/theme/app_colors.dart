import 'package:flutter/material.dart';

/// Exact translation of CropGuardPalette from Color.kt
class AppColors {
  // ─── Green Palette (Unified UI) ───────────────────────────────────────────
  static const Color primaryLight = Color(0xFF2D6A1F);
  static const Color primaryLightVariant = Color(0xFF4C9A3C);
  static const Color primaryDarkLight = Color(0xFF1A3D0A);
  static const Color backgroundLight = Color(0xFFF1F7EE);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFE2EFE0);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onBackgroundLight = Color(0xFF142612);
  static const Color onSurfaceLight = Color(0xFF142612);
  static const Color onBackgroundSecondaryLight = Color(0xFF405F3A);
  static const Color borderLight = Color(0xFFCFE2CB);
  static const Color mutedLight = Color(0xFF6B8266);
  static const Color dividerLight = Color(0xFFDEEADE);
  static const Color errorLight = Color(0xFFB00020);
  static const Color successLight = Color(0xFF4CAF50);
  static const Color warningLight = Color(0xFFFFC107);
  static const Color healthyLight = Color(0xFF43A047);
  static const Color healthyBgLight = Color(0xFFE8F5E9);
  static const Color diseaseRedLight = Color(0xFFE24B4A);
  static const Color diseaseBgLight = Color(0xFFFFF0F0);
  static const Color lowConfidenceLight = Color(0xFFEF9F27);
  static const Color lowConfidenceBgLight = Color(0xFFFDF5E4);
  static const Color accentLight = Color(0xFFD4E157);
  static const Color limeDarkLight = Color(0xFFAFB42B);
  static const Color badgeDiseasedBgLight = Color(0xFFFFF0F0);
  static const Color badgeHealthyBgLight = Color(0xFFE8F5E9);
  static const Color badgeWarningBgLight = Color(0xFFFDF5E4);
  static const Color severityEarlyLight = Color(0xFFEF9F27);
  static const Color severityModerateLight = Color(0xFFE67E22);
  static const Color severitySevereLight = Color(0xFFE24B4A);
  static const Color darkMLight = Color(0xFF162012);
  static const Color greenXLLight = Color(0xFF4C9A3C);
  static const Color infoLight = Color(0xFF1565C0);

  // ─── Legacy Palette References ───────────────────────────────────────────
  static const Color primaryDark = primaryLight;
  static const Color primaryLightDark = primaryLightVariant;
  static const Color primaryDarkDark = primaryDarkLight;
  static const Color backgroundDark = backgroundLight;
  static const Color surfaceDark = surfaceLight;
  static const Color surfaceVariantDark = surfaceVariantLight;
  static const Color onPrimaryDark = onPrimaryLight;
  static const Color onBackgroundDark = onBackgroundLight;
  static const Color onSurfaceDark = onSurfaceLight;
  static const Color onBackgroundSecondaryDark = onBackgroundSecondaryLight;
  static const Color borderDark = borderLight;
  static const Color mutedDark = mutedLight;
  static const Color dividerDark = dividerLight;
  static const Color errorDark = errorLight;
  static const Color successDark = successLight;
  static const Color warningDark = warningLight;
  static const Color healthyDark = healthyLight;
  static const Color healthyBgDark = healthyBgLight;
  static const Color diseaseRedDark = diseaseRedLight;
  static const Color diseaseBgDark = diseaseBgLight;
  static const Color lowConfidenceDark = lowConfidenceLight;
  static const Color lowConfidenceBgDark = lowConfidenceBgLight;
  static const Color accentDark = accentLight;
  static const Color limeDarkDark = limeDarkLight;
  static const Color badgeDiseasedBgDark = badgeDiseasedBgLight;
  static const Color badgeHealthyBgDark = badgeHealthyBgLight;
  static const Color badgeWarningBgDark = badgeWarningBgLight;
  static const Color severityEarlyDark = severityEarlyLight;
  static const Color severityModerateDark = severityModerateLight;
  static const Color severitySevereDark = severitySevereLight;
  static const Color darkMDark = darkMLight;
  static const Color greenXLDark = greenXLLight;
  static const Color infoDark = infoLight;
}

/// Helper class that provides context-aware colors (unified green palette)
class CropColors {
  final bool isDark;

  const CropColors({this.isDark = false});

  Color get primary => AppColors.primaryLight;
  Color get primaryLight => AppColors.primaryLightVariant;
  Color get primaryDark_ => AppColors.primaryDarkLight;
  Color get background => AppColors.backgroundLight;
  Color get surface => AppColors.surfaceLight;
  Color get surfaceVariant => AppColors.surfaceVariantLight;
  Color get onPrimary => AppColors.onPrimaryLight;
  Color get onBackground => AppColors.onBackgroundLight;
  Color get onSurface => AppColors.onSurfaceLight;
  Color get onBackgroundSecondary => AppColors.onBackgroundSecondaryLight;
  Color get border => AppColors.borderLight;
  Color get muted => AppColors.mutedLight;
  Color get divider => AppColors.dividerLight;
  Color get error => AppColors.errorLight;
  Color get success => AppColors.successLight;
  Color get warning => AppColors.warningLight;
  Color get healthy => AppColors.healthyLight;
  Color get healthyBg => AppColors.healthyBgLight;
  Color get diseaseRed => AppColors.diseaseRedLight;
  Color get diseaseBg => AppColors.diseaseBgLight;
  Color get lowConfidence => AppColors.lowConfidenceLight;
  Color get lowConfidenceBg => AppColors.lowConfidenceBgLight;
  Color get accent => AppColors.accentLight;
  Color get limeDark => AppColors.limeDarkLight;
  Color get badgeDiseasedBg => AppColors.badgeDiseasedBgLight;
  Color get badgeHealthyBg => AppColors.badgeHealthyBgLight;
  Color get badgeWarningBg => AppColors.badgeWarningBgLight;
  Color get severityEarly => AppColors.severityEarlyLight;
  Color get severityModerate => AppColors.severityModerateLight;
  Color get severitySevere => AppColors.severitySevereLight;
  Color get darkM => AppColors.darkMLight;
  Color get greenXL => AppColors.greenXLLight;
  Color get info => AppColors.infoLight;
  Color get diseaseRedBg => diseaseBg;
  Color get diseaseBadgeText => diseaseRed;
  Color get healthyBadgeText => healthy;
  Color get healthyGreen => healthy;
}

/// InheritedWidget for app-wide color access
class AppColorsScope extends InheritedWidget {
  final CropColors colors;

  const AppColorsScope({
    super.key,
    required this.colors,
    required super.child,
  });

  static CropColors of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppColorsScope>();
    return scope?.colors ?? const CropColors();
  }

  @override
  bool updateShouldNotify(AppColorsScope old) =>
      colors.isDark != old.colors.isDark;
}
