import 'dart:async';
import 'app_logger.dart';

class RetryUtils {
  RetryUtils._();

  /// Executes [operation] and retries on failure with exponential backoff.
  ///
  /// - [maxAttempts]: Max number of attempts (default 3)
  /// - [initialDelay]: Delay before first retry (default 1s)
  /// - [factor]: Exponential backoff multiplier (default 2.0)
  /// - [timeout]: Timeout applied to each individual attempt (default 10s)
  /// - [retryIf]: Predicate to filter which exceptions trigger a retry. If null, all exceptions trigger a retry.
  static Future<T> retry<T>(
    FutureOr<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double factor = 2.0,
    Duration timeout = const Duration(seconds: 10),
    bool Function(Object error)? retryIf,
  }) async {
    int attempt = 1;
    Duration delay = initialDelay;

    while (true) {
      try {
        final result = operation();
        if (result is Future<T>) {
          return await result.timeout(timeout);
        } else {
          return result;
        }
      } catch (error) {
        final isLastAttempt = attempt >= maxAttempts;
        final shouldRetry = !isLastAttempt && (retryIf == null || retryIf(error));

        if (!shouldRetry) {
          rethrow;
        }

        // Sanitize sensitive keywords from logged error
        final logMsg = error.toString().replaceAll(
          RegExp(r'key|secret|password|token', caseSensitive: false),
          '***',
        );
        AppLogger.w('Retry attempt $attempt failed: $logMsg. Retrying in ${delay.inMilliseconds}ms...');

        await Future.delayed(delay);
        attempt++;
        delay = Duration(milliseconds: (delay.inMilliseconds * factor).round());
      }
    }
  }
}
