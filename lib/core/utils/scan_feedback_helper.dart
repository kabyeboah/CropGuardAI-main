import 'dart:async';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class ScanFeedbackHelper {
  static Future<void> playScanComplete({
    required bool isHealthy,
    required bool soundEnabled,
    required bool hapticEnabled,
  }) async {
    if (soundEnabled) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
    if (hapticEnabled) {
      if (await Vibration.hasVibrator() == true) {
        unawaited(Vibration.vibrate(duration: 90));
      }
    }
  }
}
