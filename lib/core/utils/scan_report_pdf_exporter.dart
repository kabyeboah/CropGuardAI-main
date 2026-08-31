import 'package:cropguard_flutter/domain/models/detection_result.dart';

/// A placeholder implementation for PDF export functionality.
/// The real implementation would generate a PDF report for a detection
/// result and share it using platform‑specific mechanisms. For the purposes
/// of unit testing (and to allow the codebase to compile), we provide a minimal
/// stub that simply returns a completed Future.
class ScanReportPdfExporter {
  /// Shares a PDF report for the given [result].
  /// In production this would create a PDF file, store it locally, and trigger
  /// the share sheet. Here it is a no‑op async method.
  static Future<void> shareScanReport(DetectionResult result) async {
    // No‑op placeholder – intentionally does nothing.
    return;
  }

  /// Shares a combined monthly PDF report for a list of [results].
  static Future<void> shareMonthlyReport(List<DetectionResult> results) async {
    // No‑op placeholder – intentionally does nothing.
    return;
  }
}
