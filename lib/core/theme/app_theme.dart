import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'app_colors.dart';
import 'device_layout.dart';

class AppTheme {
  static ThemeData get light => _buildTheme(isDark: false);
  static ThemeData get dark => _buildTheme(isDark: true);

  static ThemeData _buildTheme({required bool isDark}) {
    final colors = CropColors(isDark: isDark);
    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        secondary: colors.accent,
        onSecondary: colors.onBackground,
        error: colors.error,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.onSurface,
        surfaceContainerHighest: colors.surfaceVariant,
        outline: colors.border,
      ),
      scaffoldBackgroundColor: colors.background,
      cardColor: colors.surface,
      dividerColor: colors.divider,
      textTheme: _buildTextTheme(colors),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onBackground,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: colors.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(DeviceLayout.buttonCornerRadius),
          ),
          minimumSize: const Size(
            double.infinity,
            DeviceLayout.primaryButtonHeight,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(DeviceLayout.buttonCornerRadius),
          ),
          minimumSize: const Size(
            double.infinity,
            DeviceLayout.secondaryButtonHeight,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.healthyBg,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.primary);
          }
          return IconThemeData(color: colors.onBackgroundSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: colors.primary,
              fontSize: 12,
              fontFamily: 'Inter',
            );
          }
          return TextStyle(
            color: colors.onBackgroundSecondary,
            fontSize: 12,
            fontFamily: 'Inter',
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        isDense: false,
        contentPadding: DeviceLayout.textFieldContentPadding,
        constraints:
            const BoxConstraints(minHeight: DeviceLayout.textFieldMinHeight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DeviceLayout.cornerRadius),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DeviceLayout.cornerRadius),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DeviceLayout.cornerRadius),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        hintStyle: TextStyle(color: colors.muted, fontSize: 15),
        labelStyle:
            TextStyle(color: colors.onBackgroundSecondary, fontSize: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return colors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.healthyBg;
          return colors.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primaryLight;
          return null;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: colors.border),
      ),
      extensions: [AppColorsThemeExtension(colors: colors)],
    );
  }

  static TextTheme _buildTextTheme(CropColors colors) {
    return TextTheme(
      displayLarge: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackground,
          fontWeight: FontWeight.bold),
      displayMedium: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackground,
          fontWeight: FontWeight.bold),
      displaySmall: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackground,
          fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackground,
          fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackground,
          fontWeight: FontWeight.w600,
          fontSize: 24),
      headlineSmall: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackground,
          fontWeight: FontWeight.w600,
          fontSize: 20),
      titleLarge: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackground,
          fontWeight: FontWeight.bold,
          fontSize: 18),
      titleMedium: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackground,
          fontWeight: FontWeight.w600,
          fontSize: 16),
      titleSmall: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackground,
          fontWeight: FontWeight.w500,
          fontSize: 14),
      bodyLarge: TextStyle(
          fontFamily: 'Inter', color: colors.onBackground, fontSize: 16),
      bodyMedium: TextStyle(
          fontFamily: 'Inter', color: colors.onBackground, fontSize: 14),
      bodySmall: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackgroundSecondary,
          fontSize: 12),
      labelLarge: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackground,
          fontWeight: FontWeight.w500,
          fontSize: 14),
      labelMedium: TextStyle(
          fontFamily: 'Inter',
          color: colors.onBackgroundSecondary,
          fontSize: 12),
      labelSmall:
          TextStyle(fontFamily: 'Inter', color: colors.muted, fontSize: 11),
    );
  }
}

/// ThemeExtension to access CropColors from any BuildContext
class AppColorsThemeExtension extends ThemeExtension<AppColorsThemeExtension> {
  final CropColors colors;

  const AppColorsThemeExtension({required this.colors});

  @override
  AppColorsThemeExtension copyWith({CropColors? colors}) =>
      AppColorsThemeExtension(colors: colors ?? this.colors);

  @override
  AppColorsThemeExtension lerp(
          ThemeExtension<AppColorsThemeExtension>? other, double t) =>
      this;
}

extension BuildContextColors on BuildContext {
  CropColors get colors {
    return Theme.of(this).extension<AppColorsThemeExtension>()?.colors ??
        const CropColors();
  }
}

extension BuildContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
