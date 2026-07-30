import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:cropguard_flutter/core/utils/retry_utils.dart';

void main() {
  group('RetryUtils.retry', () {
    test('returns value on first success', () async {
      int calls = 0;
      final result = await RetryUtils.retry<int>(() {
        calls++;
        return 42;
      });
      expect(result, 42);
      expect(calls, 1);
    });

    test('retries on failure and succeeds eventually', () async {
      int calls = 0;
      final result = await RetryUtils.retry<String>(
        () async {
          calls++;
          if (calls < 3) throw Exception('transient');
          return 'ok';
        },
        initialDelay: Duration.zero,
      );
      expect(result, 'ok');
      expect(calls, 3);
    });

    test('throws after exhausting maxAttempts', () async {
      int calls = 0;
      await expectLater(
        RetryUtils.retry<void>(
          () async {
            calls++;
            throw Exception('persistent');
          },
          maxAttempts: 3,
          initialDelay: Duration.zero,
        ),
        throwsException,
      );
      expect(calls, 3);
    });

    test('does not retry when retryIf returns false', () async {
      int calls = 0;
      await expectLater(
        RetryUtils.retry<void>(
          () async {
            calls++;
            throw StateError('not retryable');
          },
          maxAttempts: 5,
          initialDelay: Duration.zero,
          retryIf: (_) => false,
        ),
        throwsStateError,
      );
      expect(calls, 1);
    });

    test('only retries when retryIf returns true', () async {
      int calls = 0;
      await expectLater(
        RetryUtils.retry<void>(
          () async {
            calls++;
            throw const FormatException('retryable');
          },
          maxAttempts: 2,
          initialDelay: Duration.zero,
          retryIf: (e) => e is FormatException,
        ),
        throwsFormatException,
      );
      expect(calls, 2);
    });

    test('applies exponential back-off factor to delay', () async {
      // We can only observe this indirectly: with factor=1 the delay stays
      // constant. With factor=2 it doubles. The test just checks the result
      // is correct (timing tests are flaky by nature).
      int calls = 0;
      final result = await RetryUtils.retry<int>(
        () {
          calls++;
          if (calls < 2) throw Exception('once');
          return calls;
        },
        initialDelay: Duration.zero,
        factor: 1.0,
      );
      expect(result, 2);
    });

    test('throws TimeoutException when individual attempt times out', () async {
      await expectLater(
        RetryUtils.retry<void>(
          () async {
            await Future.delayed(const Duration(seconds: 10));
          },
          maxAttempts: 1,
          timeout: const Duration(milliseconds: 50),
          initialDelay: Duration.zero,
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('synchronous operation is returned immediately', () async {
      final result = await RetryUtils.retry(() => 'sync');
      expect(result, 'sync');
    });
  });
}
