import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/classifier_health_service.dart';

void main() {
  group('ClassifierHealthService', () {
    test('initial state is healthy with zero fallback count', () {
      final service = ClassifierHealthService();
      expect(service.isHealthy, isTrue);
      expect(service.fallbackCount, equals(0));
      expect(service.modelVersion, isNull);
      expect(service.lastInferenceMs, equals(0));
    });

    test('updateHealth tracks fallback and notifies listeners', () {
      final service = ClassifierHealthService();
      var notificationCount = 0;
      service.addListener(() => notificationCount++);

      service.updateHealth(
        isHealthy: false,
        usedFallback: true,
        modelVersion: 'v1-only',
        inferenceMs: 45,
      );

      expect(service.isHealthy, isFalse);
      expect(service.fallbackCount, equals(1));
      expect(service.modelVersion, equals('v1-only'));
      expect(service.lastInferenceMs, equals(45));
      expect(notificationCount, equals(1));

      service.updateHealth(
        isHealthy: true,
        usedFallback: true,
      );
      expect(service.fallbackCount, equals(2));
      expect(notificationCount, equals(2));
    });

    test('resetFallbackCount resets counter to zero', () {
      final service = ClassifierHealthService();
      service.updateHealth(isHealthy: true, usedFallback: true);
      expect(service.fallbackCount, equals(1));

      service.resetFallbackCount();
      expect(service.fallbackCount, equals(0));
    });
  });
}
