import 'package:flutter/material.dart';

/// Exact translation of CropGuardPalette from Color.kt
class AppColors {
  // ─── Light Palette ───────────────────────────────────────────────────────
  static const Color primaryLight = Color(0xFF2D6A1F);
  static const Color primaryLightVariant = Color(0xFF4C9A3C);
  static const Color primaryDarkLight = Color(0xFF1A3D0A);
  static const Color backgroundLight = Color(0xFFF9FBF8);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5EF);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onBackgroundLight = Color(0xFF1A1A1A);
  static const Color onSurfaceLight = Color(0xFF1A1A1A);
  static const Color onBackgroundSecondaryLight = Color(0xFF666666);
  static const Color borderLight = Color(0xFFE0E6DD);
  static const Color mutedLight = Color(0xFF888888);
  static const Color dividerLight = Color(0xFFEEEEEE);
  static const Color errorLight = Color(0xFFB00020);
  static const Color successLight = Color(0xFF4CAF50);
  static const Color warningLight = Color(0xFFFFC107);
  static const Color healthyLight = Color(0xFF639922);
  static const Color healthyBgLight = Color(0xFFF0F9EB);
  static const Color diseaseRedLight = Color(0xFFE24B4A);
  static const Color diseaseBgLight = Color(0xFFFFF0F0);
  static const Color lowConfidenceLight = Color(0xFFEF9F27);
  static const Color lowConfidenceBgLight = Color(0xFFFDF5E4);
  static const Color accentLight = Color(0xFFD4E157);
  static const Color limeDarkLight = Color(0xFFAFB42B);
  static const Color badgeDiseasedBgLight = Color(0xFFFFF0F0);
  static const Color badgeHealthyBgLight = Color(0xFFF0F9EB);
  static const Color badgeWarningBgLight = Color(0xFFFDF5E4);
  static const Color severityEarlyLight = Color(0xFFEF9F27);
  static const Color severityModerateLight = Color(0xFFE67E22);
  static const Color severitySevereLight = Color(0xFFE24B4A);
  static const Color darkMLight = Color(0xFF162012);
  static const Color greenXLLight = Color(0xFF4C9A3C);
  static const Color infoLight = Color(0xFF1565C0);

  // ─── Dark Palette ────────────────────────────────────────────────────────
  static const Color primaryDark = Color(0xFF4C9A3C);
  static const Color primaryLightDark = Color(0xFF76C35F);
  static const Color primaryDarkDark = Color(0xFF2D6A1F);
  static const Color backgroundDark = Color(0xFF0C1409);
  static const Color surfaceDark = Color(0xFF162012);
  static const Color surfaceVariantDark = Color(0xFF253320);
  static const Color onPrimaryDark = Color(0xFFFFFFFF);
  static const Color onBackgroundDark = Color(0xFFE8F0E5);
  static const Color onSurfaceDark = Color(0xFFE8F0E5);
  static const Color onBackgroundSecondaryDark = Color(0xFFA8B5A5);
  static const Color borderDark = Color(0xFF2D3B28);
  static const Color mutedDark = Color(0xFF7A8678);
  static const Color dividerDark = Color(0xFF1F2B1A);
  static const Color errorDark = Color(0xFFCF6679);
  static const Color successDark = Color(0xFF81C784);
  static const Color warningDark = Color(0xFFFFD54F);
  static const Color healthyDark = Color(0xFF9CCC65);
  static const Color healthyBgDark = Color(0xFF1B2B13);
  static const Color diseaseRedDark = Color(0xFFEF5350);
  static const Color diseaseBgDark = Color(0xFF331A1A);
  static const Color lowConfidenceDark = Color(0xFFFFB74D);
  static const Color lowConfidenceBgDark = Color(0xFF2E2413);
  static const Color accentDark = Color(0xFFE6EE9C);
  static const Color limeDarkDark = Color(0xFFC0CA33);
  static const Color badgeDiseasedBgDark = Color(0xFF331A1A);
  static const Color badgeHealthyBgDark = Color(0xFF1B2B13);
  static const Color badgeWarningBgDark = Color(0xFF2E2413);
  static const Color severityEarlyDark = Color(0xFFFFB74D);
  static const Color severityModerateDark = Color(0xFFFB8C00);
  static const Color severitySevereDark = Color(0xFFEF5350);
  static const Color darkMDark = Color(0xFF0C1409);
  static const Color greenXLDark = Color(0xFF76C35F);
  static const Color infoDark = Color(0xFF90CAF9);
}

/// Helper class that provides context-aware colors (similar to LocalCropGuardColors)
class CropColors {
  final bool isDark;

  const CropColors({this.isDark = false});

  Color get primary => isDark ? AppColors.primaryDark : AppColors.primaryLight;
  Color get primaryLight => isDark ? AppColors.primaryLightDark : AppColors.primaryLightVariant;
  Color get primaryDark_ => isDark ? AppColors.primaryDarkDark : AppColors.primaryDarkLight;
  Color get background => isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
  Color get surface => isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get surfaceVariant => isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight;
  Color get onPrimary => isDark ? AppColors.onPrimaryDark : AppColors.onPrimaryLight;
  Color get onBackground => isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight;
  Color get onSurface => isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight;
  Color get onBackgroundSecondary => isDark ? AppColors.onBackgroundSecondaryDark : AppColors.onBackgroundSecondaryLight;
  Color get border => isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get muted => isDark ? AppColors.mutedDark : AppColors.mutedLight;
  Color get divider => isDark ? AppColors.dividerDark : AppColors.dividerLight;
  Color get error => isDark ? AppColors.errorDark : AppColors.errorLight;
  Color get success => isDark ? AppColors.successDark : AppColors.successLight;
  Color get warning => isDark ? AppColors.warningDark : AppColors.warningLight;
  Color get healthy => isDark ? AppColors.healthyDark : AppColors.healthyLight;
  Color get healthyBg => isDark ? AppColors.healthyBgDark : AppColors.healthyBgLight;
  Color get diseaseRed => isDark ? AppColors.diseaseRedDark : AppColors.diseaseRedLight;
  Color get diseaseBg => isDark ? AppColors.diseaseBgDark : AppColors.diseaseBgLight;
  Color get lowConfidence => isDark ? AppColors.lowConfidenceDark : AppColors.lowConfidenceLight;
  Color get lowConfidenceBg => isDark ? AppColors.lowConfidenceBgDark : AppColors.lowConfidenceBgLight;
  Color get accent => isDark ? AppColors.accentDark : AppColors.accentLight;
  Color get limeDark => isDark ? AppColors.limeDarkDark : AppColors.limeDarkLight;
  Color get badgeDiseasedBg => isDark ? AppColors.badgeDiseasedBgDark : AppColors.badgeDiseasedBgLight;
  Color get badgeHealthyBg => isDark ? AppColors.badgeHealthyBgDark : AppColors.badgeHealthyBgLight;
  Color get badgeWarningBg => isDark ? AppColors.badgeWarningBgDark : AppColors.badgeWarningBgLight;
  Color get severityEarly => isDark ? AppColors.severityEarlyDark : AppColors.severityEarlyLight;
  Color get severityModerate => isDark ? AppColors.severityModerateDark : AppColors.severityModerateLight;
  Color get severitySevere => isDark ? AppColors.severitySevereDark : AppColors.severitySevereLight;
  Color get darkM => isDark ? AppColors.darkMDark : AppColors.darkMLight;
  Color get greenXL => isDark ? AppColors.greenXLDark : AppColors.greenXLLight;
  Color get info => isDark ? AppColors.infoDark : AppColors.infoLight;
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
  bool updateShouldNotify(AppColorsScope old) => colors.isDark != old.colors.isDark;
}
