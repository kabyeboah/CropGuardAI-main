import 'dart:collection';

/// Result of a rate limit check.
class RateLimitResult {
  final bool isAllowed;
  final Duration? retryAfter;
  final String? message;

  const RateLimitResult.allowed()
      : isAllowed = true,
        retryAfter = null,
        message = null;

  const RateLimitResult.denied(
      {required this.retryAfter, required this.message})
      : isAllowed = false;
}

/// Generic, in-memory sliding-window and cooldown rate limiter.
class RateLimiter {
  // Store timestamps of actions per key: Map<actionKey, Queue<DateTime>>
  final Map<String, Queue<DateTime>> _actionTimestamps = {};
  final Map<String, DateTime> _lastActionTime = {};

  /// Checks if an action is allowed given a minimum [cooldown] between actions,
  /// and/or a sliding window of [maxPerWindow] actions within [windowDuration].
  ///
  /// If [recordOnCheck] is true, records the current timestamp if the action is allowed.
  RateLimitResult checkLimit(
    String actionKey, {
    Duration cooldown = Duration.zero,
    int maxPerWindow = 0,
    Duration windowDuration = Duration.zero,
    bool recordOnCheck = true,
  }) {
    final now = DateTime.now();

    // 1. Check cooldown
    if (cooldown > Duration.zero && _lastActionTime.containsKey(actionKey)) {
      final lastTime = _lastActionTime[actionKey]!;
      final elapsed = now.difference(lastTime);
      if (elapsed < cooldown) {
        final remaining = cooldown - elapsed;
        final seconds = (remaining.inMilliseconds / 1000).ceil();
        return RateLimitResult.denied(
          retryAfter: remaining,
          message:
              'Please wait $seconds second${seconds == 1 ? '' : 's'} before trying again.',
        );
      }
    }

    // 2. Check sliding window limit
    if (maxPerWindow > 0 && windowDuration > Duration.zero) {
      final timestamps =
          _actionTimestamps.putIfAbsent(actionKey, () => Queue<DateTime>());

      // Evict expired timestamps
      final cutoff = now.subtract(windowDuration);
      while (timestamps.isNotEmpty && timestamps.first.isBefore(cutoff)) {
        timestamps.removeFirst();
      }

      if (timestamps.length >= maxPerWindow) {
        final oldest = timestamps.first;
        final timeToWait = oldest.add(windowDuration).difference(now);
        final seconds = (timeToWait.inMilliseconds / 1000)
            .ceil()
            .clamp(1, windowDuration.inSeconds);
        return RateLimitResult.denied(
          retryAfter: timeToWait,
          message:
              'Rate limit exceeded. Please wait $seconds second${seconds == 1 ? '' : 's'}.',
        );
      }
    }

    // Allowed
    if (recordOnCheck) {
      recordAction(actionKey);
    }

    return const RateLimitResult.allowed();
  }

  /// Manually records that an action occurred at the current time.
  void recordAction(String actionKey) {
    final now = DateTime.now();
    _lastActionTime[actionKey] = now;
    final timestamps =
        _actionTimestamps.putIfAbsent(actionKey, () => Queue<DateTime>());
    timestamps.addLast(now);
  }

  /// Clears rate limit history for a key or all keys.
  void reset([String? actionKey]) {
    if (actionKey != null) {
      _actionTimestamps.remove(actionKey);
      _lastActionTime.remove(actionKey);
    } else {
      _actionTimestamps.clear();
      _lastActionTime.clear();
    }
  }
}
