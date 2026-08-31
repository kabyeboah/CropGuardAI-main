import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/notification_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationHelper', () {
    test('init executes without crashing', () async {
      expect(NotificationHelper.init, isNotNull);
    });

    test('generateUniqueId returns 31-bit positive integers', () {
      for (int i = 0; i < 100; i++) {
        final id = NotificationHelper.generateUniqueId();
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });

    test(
        'generateUniqueId produces unique distinct ids across successive rapid calls',
        () {
      final ids = <int>{};
      for (int i = 0; i < 50; i++) {
        final id = NotificationHelper.generateUniqueId();
        expect(ids.contains(id), isFalse, reason: 'ID $id should be unique');
        ids.add(id);
      }
      expect(ids.length, 50);
    });
  });
}
