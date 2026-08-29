import 'package:flutter/material.dart';
import '../../../domain/models/detection_result.dart';
import '../../../core/utils/scan_severity.dart';

class BatchScanResult {
  final int totalLeaves;
  final int diseasedLeaves;
  final String dominantDisease;
  final String overallSeverity;
  final List<DetectionResult> results;
  final String aggregatedSummary;

  const BatchScanResult({
    required this.totalLeaves,
    required this.diseasedLeaves,
    required this.dominantDisease,
    required this.overallSeverity,
    required this.results,
    required this.aggregatedSummary,
  });
}

class BatchResultProvider extends ChangeNotifier {
  BatchScanResult? batchResult;
  bool isLoading = false;

  void calculateResults(List<DetectionResult> results) {
    isLoading = true;
    notifyListeners();

    if (results.isNotEmpty) {
      final totalLeaves = results.length;
      final diseasedResults = results.where((r) => !r.isHealthy).toList();
      final diseasedLeaves = diseasedResults.length;

      String dominantDisease = "Healthy";
      if (diseasedResults.isNotEmpty) {
        final counts = <String, int>{};
        for (var r in diseasedResults) {
          counts[r.displayName] = (counts[r.displayName] ?? 0) + 1;
        }
        dominantDisease = counts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      String overallSeverity = ScanSeverity.healthy;
      if (diseasedLeaves > 0) {
        const severityRank = {
          ScanSeverity.severe: 4,
          ScanSeverity.moderate: 3,
          ScanSeverity.early: 2,
          ScanSeverity.unclear: 1,
          ScanSeverity.healthy: 0,
        };

        overallSeverity = diseasedResults
            .map((r) => r.severity)
            .reduce((a, b) => (severityRank[a] ?? 1) >= (severityRank[b] ?? 1) ? a : b);
      }

      String aggregatedSummary;
      if (diseasedLeaves > 0) {
        aggregatedSummary =
            "$diseasedLeaves of $totalLeaves leaves show $dominantDisease — ${overallSeverity[0].toUpperCase()}${overallSeverity.substring(1)} infection level.";
      } else {
        aggregatedSummary = "All $totalLeaves leaves appear healthy.";
      }

      batchResult = BatchScanResult(
        totalLeaves: totalLeaves,
        diseasedLeaves: diseasedLeaves,
        dominantDisease: dominantDisease,
        overallSeverity: overallSeverity,
        results: results,
        aggregatedSummary: aggregatedSummary,
      );
    }

    isLoading = false;
    notifyListeners();
  }
}
