import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/rate_limiter.dart';

void main() {
  late RateLimiter rateLimiter;

  setUp(() {
    rateLimiter = RateLimiter();
  });

  group('RateLimiter', () {
    test('allows initial action when no prior history', () {
      final res = rateLimiter.checkLimit('test_action',
          cooldown: const Duration(seconds: 10));
      expect(res.isAllowed, isTrue);
      expect(res.retryAfter, isNull);
      expect(res.message, isNull);
    });

    test('enforces cooldown period between actions', () {
      final res1 = rateLimiter.checkLimit('post_user1',
          cooldown: const Duration(seconds: 30));
      expect(res1.isAllowed, isTrue);

      // Immediate follow-up should be denied
      final res2 = rateLimiter.checkLimit('post_user1',
          cooldown: const Duration(seconds: 30));
      expect(res2.isAllowed, isFalse);
      expect(res2.message, contains('Please wait'));
      expect(res2.retryAfter, isNotNull);
    });

    test('enforces max actions per sliding window', () {
      const key = 'reports_user1';
      for (int i = 0; i < 3; i++) {
        final res = rateLimiter.checkLimit(
          key,
          maxPerWindow: 3,
          windowDuration: const Duration(minutes: 1),
        );
        expect(res.isAllowed, isTrue);
      }

      // 4th action should be denied
      final blocked = rateLimiter.checkLimit(
        key,
        maxPerWindow: 3,
        windowDuration: const Duration(minutes: 1),
      );
      expect(blocked.isAllowed, isFalse);
      expect(blocked.message, contains('Rate limit exceeded'));
    });

    test('independent keys do not interfere with each other', () {
      rateLimiter.checkLimit('user_A', cooldown: const Duration(seconds: 30));
      final resB = rateLimiter.checkLimit('user_B',
          cooldown: const Duration(seconds: 30));
      expect(resB.isAllowed, isTrue);
    });

    test('reset clears action history', () {
      rateLimiter.checkLimit('user_A', cooldown: const Duration(seconds: 30));
      rateLimiter.reset('user_A');

      final res = rateLimiter.checkLimit('user_A',
          cooldown: const Duration(seconds: 30));
      expect(res.isAllowed, isTrue);
    });
  });
}
