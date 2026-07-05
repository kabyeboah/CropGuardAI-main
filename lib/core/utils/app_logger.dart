import 'dart:developer' as dev;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static void d(String message) {
    if (kDebugMode) {
      dev.log('DEBUG: $message', name: 'CropGuard');
    }
  }

  static void i(String message) {
    dev.log('INFO: $message', name: 'CropGuard');
  }

  static void w(String message) {
    dev.log('WARNING: $message', name: 'CropGuard');
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    dev.log(
      'ERROR: $message',
      name: 'CropGuard',
      error: error,
      stackTrace: stackTrace,
    );
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
