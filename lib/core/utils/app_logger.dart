import 'dart:developer' as dev;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.error;

  static void d(String message) {
    if (LogLevel.debug.index >= minLevel.index && kDebugMode) {
      dev.log('DEBUG: $message', name: 'CropGuard');
    }
  }

  static void i(String message) {
    if (LogLevel.info.index >= minLevel.index && kDebugMode) {
      dev.log('INFO: $message', name: 'CropGuard');
    }
  }

  static void w(String message) {
    if (LogLevel.warning.index >= minLevel.index && kDebugMode) {
      dev.log('WARNING: $message', name: 'CropGuard');
    }
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    if (LogLevel.error.index >= minLevel.index) {
      dev.log(
        'ERROR: $message',
        name: 'CropGuard',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordError(
        error ?? Exception(message),
        stackTrace ?? StackTrace.current,
        reason: message,
        fatal: false,
      );
    }
  }
}
