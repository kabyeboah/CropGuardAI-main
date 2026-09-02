import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import 'diagnostic_sanitizer.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.error;

  /// Whether crash/error reporting is enabled (synced with user consent).
  /// Defaults to false (strict opt-in).
  static bool isCrashlyticsEnabled = false;

  static void setCrashlyticsEnabled(bool enabled) {
    isCrashlyticsEnabled = enabled;
  }

  static void d(String message) {
    if (LogLevel.debug.index >= minLevel.index && kDebugMode) {
      final clean = DiagnosticSanitizer.sanitizeString(message);
      dev.log('DEBUG: $clean', name: 'CropGuard');
    }
  }

  static void i(String message) {
    if (LogLevel.info.index >= minLevel.index && kDebugMode) {
      final clean = DiagnosticSanitizer.sanitizeString(message);
      dev.log('INFO: $clean', name: 'CropGuard');
    }
  }

  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    if (LogLevel.warning.index >= minLevel.index && kDebugMode) {
      final cleanMsg = DiagnosticSanitizer.sanitizeString(message);
      final cleanErr =
          error != null ? DiagnosticSanitizer.sanitizeError(error) : null;
      final cleanStack = DiagnosticSanitizer.sanitizeStackTrace(stackTrace);
      dev.log(
        'WARNING: $cleanMsg',
        name: 'CropGuard',
        error: cleanErr,
        stackTrace: cleanStack,
      );
    }
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    final cleanMsg = DiagnosticSanitizer.sanitizeString(message);
    final cleanErr =
        DiagnosticSanitizer.sanitizeError(error ?? Exception(message));
    final cleanStack = DiagnosticSanitizer.sanitizeStackTrace(
        stackTrace ?? StackTrace.current);

    if (LogLevel.error.index >= minLevel.index) {
      dev.log(
        'ERROR: $cleanMsg',
        name: 'CropGuard',
        error: cleanErr,
        stackTrace: cleanStack,
      );
    }
  }
}
