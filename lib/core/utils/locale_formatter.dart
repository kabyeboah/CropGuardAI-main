import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Utility to format dates and numbers safely across standard and custom locales.
/// If localizations/symbols for a custom locale (like tw, ee, dag) are missing,
/// it falls back gracefully to a language-only locale, and then to English ('en').
class LocaleFormatter {
  static String formatMonthDay(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = _getSafeDateFormat('MMM d', locale);
    return formatter.format(dateTime);
  }

  static String formatMonthDayYear(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = _getSafeDateFormat('MMM d, yyyy', locale);
    return formatter.format(dateTime);
  }

  static String formatMonthDayYearHourMinute(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = _getSafeDateFormat('MMM d, yyyy HH:mm', locale);
    return formatter.format(dateTime);
  }

  static String formatMonthDayHourMinute(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = _getSafeDateFormat('MMM d, HH:mm', locale);
    return formatter.format(dateTime);
  }

  static String formatDayOfWeek(BuildContext context, DateTime dateTime) {
    final locale = Localizations.localeOf(context).toString();
    final formatter = _getSafeDateFormat('E', locale);
    return formatter.format(dateTime);
  }

  static String formatNumber(BuildContext context, num value) {
    final locale = Localizations.localeOf(context).toString();
    try {
      final formatter = NumberFormat.decimalPattern(locale);
      return formatter.format(value);
    } catch (_) {
      try {
        final lang = locale.split('_')[0];
        final formatter = NumberFormat.decimalPattern(lang);
        return formatter.format(value);
      } catch (_) {
        return NumberFormat.decimalPattern('en').format(value);
      }
    }
  }

  static DateFormat _getSafeDateFormat(String pattern, String locale) {
    try {
      return DateFormat(pattern, locale);
    } catch (_) {
      try {
        final lang = locale.split('_')[0];
        return DateFormat(pattern, lang);
      } catch (_) {
        return DateFormat(pattern, 'en');
      }
    }
  }
}
