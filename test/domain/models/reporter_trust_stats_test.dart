import 'package:cropguard_flutter/domain/models/reporter_trust_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReporterTrustStats Tests', () {
    test('calculates Novice Observer tier correctly for low activity', () {
      final stats = ReporterTrustStats.calculate(
        totalSubmitted: 2,
        verifiedReports: 1,
        verificationsGiven: 2,
      );

      expect(stats.trustScore, equals(14)); // (1*10) + (2*2) = 14
      expect(stats.reputationBadgeTitle, equals('🌱 Novice Observer'));
    });

    test('calculates Field Reporter tier correctly', () {
      final stats = ReporterTrustStats.calculate(
        totalSubmitted: 5,
        verifiedReports: 3,
        verificationsGiven: 5,
      );

      expect(stats.trustScore, equals(40)); // (3*10) + (5*2) = 40
      expect(stats.reputationBadgeTitle, equals('🌿 Field Reporter'));
    });

    test('calculates Trusted Sentinel tier correctly', () {
      final stats = ReporterTrustStats.calculate(
        totalSubmitted: 15,
        verifiedReports: 8,
        verificationsGiven: 10,
      );

      expect(stats.trustScore, equals(100)); // (8*10) + (10*2) = 100
      expect(stats.reputationBadgeTitle, equals('🛡️ Trusted Sentinel'));
    });

    test('calculates Master Guardian tier correctly', () {
      final stats = ReporterTrustStats.calculate(
        totalSubmitted: 25,
        verifiedReports: 15,
        verificationsGiven: 20,
      );

      expect(stats.trustScore, equals(190)); // (15*10) + (20*2) = 190
      expect(stats.reputationBadgeTitle, equals('🏅 Master Guardian'));
    });

    test('serializes and deserializes fromMap and toMap correctly', () {
      const stats = ReporterTrustStats(
        totalSubmittedReports: 10,
        verifiedReportsCount: 6,
        verificationsGivenCount: 12,
        trustScore: 84,
        reputationBadgeTitle: '🛡️ Trusted Sentinel',
      );

      final map = stats.toMap();
      final reconstructed = ReporterTrustStats.fromMap(map);

      expect(reconstructed.totalSubmittedReports, equals(10));
      expect(reconstructed.verifiedReportsCount, equals(6));
      expect(reconstructed.verificationsGivenCount, equals(12));
      expect(reconstructed.trustScore, equals(84));
      expect(
          reconstructed.reputationBadgeTitle, equals('🛡️ Trusted Sentinel'));
    });
  });
}
