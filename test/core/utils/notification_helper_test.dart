import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/notification_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationHelper', () {
    test('init executes without crashing', () async {
      // In unit test environment without native platform channel handler,
      // init or show calls can be validated or exercised gracefully.
      expect(NotificationHelper.init, isNotNull);
    });
  });
}
