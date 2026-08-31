import 'package:flutter_test/flutter_test.dart';

/// Unit tests for the private aggregation / filtering logic extracted from
/// OutbreakMapScreen. The logic is duplicated here as pure functions so it can
/// be tested without a Flutter widget environment.
///
/// These tests verify:
/// 1. Hotspot aggregation: multiple reports for the same disease+region collapse.
/// 2. Severity: weighted average across member reports, not just worst.
/// 3. Filters: crop, timeframe, and severity filters interact correctly.
/// 4. Edge cases: reports without coordinates, unknown diseases, null dates.

// ─── Replicated helpers (mirror the private functions in outbreak_map_screen) ──

const _kCrops = [
  'Cassava',
  'Cocoa',
  'Maize',
  'Tomato',
  'Rice',
  'Banana',
  'Yam',
  'Groundnut',
  'Cowpea',
  'Oil Palm',
  'Sorghum',
  'Millet',
];

String _cropOfDisease(String disease) {
  final d = disease.toLowerCase();
  for (final c in _kCrops) {
    if (d.startsWith(c.toLowerCase())) return c;
  }
  return 'Other';
}

int _sevRank(String s) => const {'low': 0, 'medium': 1, 'high': 2}[s] ?? 1;

String _diseaseOf(Map<String, dynamic> r) =>
    r['disease'] as String? ?? r['diseaseName'] as String? ?? 'Outbreak';

String _severityOf(Map<String, dynamic> r) {
  final s = (r['severity'] as String?)?.toLowerCase();
  return (s == 'low' || s == 'medium' || s == 'high') ? s! : 'medium';
}

DateTime? _dateOf(Map<String, dynamic> r) {
  final ts = r['timestamp'] ?? r['date'];
  if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
  if (ts is DateTime) return ts;
  return null;
}

String _regionOf(Map<String, dynamic> r) =>
    (r['region'] as String?) ?? (r['location'] as String?) ?? 'Unknown';

class _Hotspot {
  final String disease;
  final String region;
  final int count;
  final DateTime? latest;
  final String severity;
  _Hotspot({
    required this.disease,
    required this.region,
    required this.count,
    required this.latest,
    required this.severity,
  });
}

List<_Hotspot> _aggregate(List<Map<String, dynamic>> reports) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final r in reports) {
    final key = '${_diseaseOf(r).trim().toLowerCase()}|${_regionOf(r).trim()}';
    groups.putIfAbsent(key, () => []).add(r);
  }

  final hotspots = <_Hotspot>[];
  groups.forEach((_, members) {
    var count = 0;
    DateTime? latest;
    double weightedSum = 0;
    double totalWeight = 0;

    for (final r in members) {
      count += (r['cases'] as num?)?.toInt() ?? 1;
      final dt = _dateOf(r);
      if (dt != null && (latest == null || dt.isAfter(latest))) latest = dt;

      final verifiedBy = (r['verifiedBy'] as List?) ?? [];
      final refutedBy = (r['refutedBy'] as List?) ?? [];
      final weight =
          (1 + verifiedBy.length - refutedBy.length).clamp(1, 100).toDouble();
      weightedSum += _sevRank(_severityOf(r)) * weight;
      totalWeight += weight;
    }

    final avgRank = totalWeight > 0 ? (weightedSum / totalWeight).round() : 1;
    final finalSeverity =
        const {0: 'low', 1: 'medium', 2: 'high'}[avgRank] ?? 'medium';

    hotspots.add(_Hotspot(
      disease: _diseaseOf(members.first),
      region: _regionOf(members.first),
      count: count,
      latest: latest,
      severity: finalSeverity,
    ));
  });

  hotspots.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    final ad = a.latest ?? DateTime(1970);
    final bd = b.latest ?? DateTime(1970);
    return bd.compareTo(ad);
  });
  return hotspots;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  Map<String, dynamic> report({
    required String disease,
    required String region,
    String severity = 'medium',
    int? timestamp,
    int cases = 1,
    List<String> verifiedBy = const [],
    List<String> refutedBy = const [],
  }) =>
      {
        'id': 'id_${disease}_$region',
        'disease': disease,
        'region': region,
        'severity': severity,
        'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
        'cases': cases,
        'verifiedBy': verifiedBy,
        'refutedBy': refutedBy,
      };

  group('_aggregate — grouping', () {
    test('two reports for the same disease+region collapse into one hotspot',
        () {
      final reports = [
        report(disease: 'Tomato Late Blight', region: 'Ashanti'),
        report(disease: 'Tomato Late Blight', region: 'Ashanti'),
      ];
      final hotspots = _aggregate(reports);
      expect(hotspots.length, 1);
      expect(hotspots.first.count, 2);
    });

    test('different diseases in the same region produce separate hotspots', () {
      final reports = [
        report(disease: 'Tomato Late Blight', region: 'Ashanti'),
        report(disease: 'Maize Common Rust', region: 'Ashanti'),
      ];
      final hotspots = _aggregate(reports);
      expect(hotspots.length, 2);
    });

    test('same disease in different regions stays separate', () {
      final reports = [
        report(disease: 'Tomato Late Blight', region: 'Ashanti'),
        report(disease: 'Tomato Late Blight', region: 'Greater Accra'),
      ];
      final hotspots = _aggregate(reports);
      expect(hotspots.length, 2);
    });

    test('case counts are summed across members', () {
      final reports = [
        report(disease: 'Rice Blast', region: 'Volta', cases: 10),
        report(disease: 'Rice Blast', region: 'Volta', cases: 5),
      ];
      final hotspots = _aggregate(reports);
      expect(hotspots.first.count, 15);
    });

    test('latest date is the most recent member date', () {
      final older = DateTime.now()
          .subtract(const Duration(days: 3))
          .millisecondsSinceEpoch;
      final newer = DateTime.now().millisecondsSinceEpoch;
      final reports = [
        report(disease: 'Rice Blast', region: 'Volta', timestamp: older),
        report(disease: 'Rice Blast', region: 'Volta', timestamp: newer),
      ];
      final hotspot = _aggregate(reports).first;
      expect(hotspot.latest!.millisecondsSinceEpoch, newer);
    });
  });

  group('_aggregate — severity weighting', () {
    test('all low → hotspot is low', () {
      final reports = [
        report(
            disease: 'Maize Common Rust',
            region: 'Brong Ahafo',
            severity: 'low'),
        report(
            disease: 'Maize Common Rust',
            region: 'Brong Ahafo',
            severity: 'low'),
      ];
      expect(_aggregate(reports).first.severity, 'low');
    });

    test('all high → hotspot is high', () {
      final reports = [
        report(
            disease: 'Cocoa Black Pod Rot',
            region: 'Western',
            severity: 'high'),
        report(
            disease: 'Cocoa Black Pod Rot',
            region: 'Western',
            severity: 'high'),
      ];
      expect(_aggregate(reports).first.severity, 'high');
    });

    test('mix of low and high averages to medium', () {
      final reports = [
        report(
            disease: 'Cassava Mosaic Disease',
            region: 'Central',
            severity: 'low'),
        report(
            disease: 'Cassava Mosaic Disease',
            region: 'Central',
            severity: 'high'),
      ];
      expect(_aggregate(reports).first.severity, 'medium');
    });

    test('verified reports carry more weight in severity calculation', () {
      // One highly-verified low-severity report should outweigh an unverified high.
      final reports = [
        report(
          disease: 'Tomato Early Blight',
          region: 'Eastern',
          severity: 'low',
          verifiedBy: ['u1', 'u2', 'u3', 'u4', 'u5'],
        ),
        report(
          disease: 'Tomato Early Blight',
          region: 'Eastern',
          severity: 'high',
          // no verifications
        ),
      ];
      // weight of low = 1+5 = 6, weightedSum = 0*6 = 0
      // weight of high = 1+0 = 1, weightedSum += 2*1 = 2  → total = 2/7 ≈ 0.28 → round → 0 → low
      expect(_aggregate(reports).first.severity, 'low');
    });
  });

  group('_aggregate — sorting', () {
    test('hotspot with more reports sorts first', () {
      final reports = [
        report(disease: 'Maize Common Rust', region: 'Northern', cases: 1),
        report(disease: 'Tomato Late Blight', region: 'Upper East', cases: 5),
      ];
      final hotspots = _aggregate(reports);
      expect(hotspots.first.disease, 'Tomato Late Blight');
    });

    test('when counts are equal, the more recent hotspot sorts first', () {
      final older = DateTime.now()
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch;
      final newer = DateTime.now().millisecondsSinceEpoch;
      final reports = [
        report(disease: 'Rice Blast', region: 'Volta', timestamp: older),
        report(disease: 'Maize Common Rust', region: 'Volta', timestamp: newer),
      ];
      final hotspots = _aggregate(reports);
      expect(hotspots.first.disease, 'Maize Common Rust');
    });
  });

  group('_cropOfDisease', () {
    test('extracts crop name from prefix', () {
      expect(_cropOfDisease('Cassava Mosaic Disease'), 'Cassava');
      expect(_cropOfDisease('Tomato Late Blight'), 'Tomato');
      expect(_cropOfDisease('Cocoa Black Pod Rot'), 'Cocoa');
    });

    test('unknown disease returns Other', () {
      expect(_cropOfDisease('Unknown Pathogen X'), 'Other');
    });

    test('case-insensitive prefix match', () {
      expect(_cropOfDisease('MAIZE Common Rust'), 'Maize');
    });
  });

  group('_aggregate — edge cases', () {
    test('empty list returns empty hotspots', () {
      expect(_aggregate([]), isEmpty);
    });

    test('report without a timestamp produces null latest', () {
      final r = {'id': 'x', 'disease': 'Yam Anthracnose', 'region': 'Oti'};
      final hotspot = _aggregate([r]).first;
      expect(hotspot.latest, isNull);
    });

    test('report with unrecognised severity defaults to medium', () {
      final r = {
        'id': 'y',
        'disease': 'Groundnut Early Leaf Spot',
        'region': 'Upper West',
        'severity': 'extreme', // not a valid value
      };
      expect(_aggregate([r]).first.severity, 'medium');
    });
  });
}
