import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

class RootDetectionHelper {
  static Future<bool> isRooted() async {
    try {
      return await FlutterJailbreakDetection.jailbroken;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isDeveloperMode() async {
    try {
      return await FlutterJailbreakDetection.developerMode;
    } catch (e) {
      return false;
    }
  }
}
