import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/scan_feedback_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScanFeedbackHelper Tests', () {
    final List<MethodCall> systemChannelCalls = <MethodCall>[];

    setUp(() {
      systemChannelCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        systemChannelCalls.add(methodCall);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('plays system sound when soundEnabled is true', () async {
      await ScanFeedbackHelper.playScanComplete(
        isHealthy: true,
        soundEnabled: true,
        hapticEnabled: false,
      );

      expect(
        systemChannelCalls.any(
          (call) =>
              call.method == 'SystemSound.play' &&
              call.arguments == SystemSoundType.click.toString(),
        ),
        isTrue,
      );
    });

    test('does not play system sound when soundEnabled is false', () async {
      await ScanFeedbackHelper.playScanComplete(
        isHealthy: true,
        soundEnabled: false,
        hapticEnabled: false,
      );

      expect(
        systemChannelCalls.any((call) => call.method == 'SystemSound.play'),
        isFalse,
      );
    });
  });
}
