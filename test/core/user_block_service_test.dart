import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cropguard_flutter/core/utils/user_block_service.dart';

void main() {
  group('UserBlockService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('initial state has no blocked users', () {
      final service = UserBlockService(prefs);
      expect(service.blockedUserIds, isEmpty);
      expect(service.isBlocked('user_123'), isFalse);
    });

    test('blocking a user adds to set and persists to SharedPreferences',
        () async {
      final service = UserBlockService(prefs);
      bool notified = false;
      service.addListener(() => notified = true);

      await service.blockUser('spammer_01');

      expect(service.isBlocked('spammer_01'), isTrue);
      expect(service.blockedUserIds.contains('spammer_01'), isTrue);
      expect(notified, isTrue);

      // Verify persistence by initializing a second instance
      final service2 = UserBlockService(prefs);
      expect(service2.isBlocked('spammer_01'), isTrue);
    });

    test('unblocking a user removes them and updates storage', () async {
      final service = UserBlockService(prefs);
      await service.blockUser('spammer_01');
      expect(service.isBlocked('spammer_01'), isTrue);

      await service.unblockUser('spammer_01');
      expect(service.isBlocked('spammer_01'), isFalse);

      final service2 = UserBlockService(prefs);
      expect(service2.isBlocked('spammer_01'), isFalse);
    });

    test('clearAll removes all blocked users', () async {
      final service = UserBlockService(prefs);
      await service.blockUser('user_1');
      await service.blockUser('user_2');
      expect(service.blockedUserIds.length, 2);

      await service.clearAll();
      expect(service.blockedUserIds, isEmpty);
    });
  });
}
