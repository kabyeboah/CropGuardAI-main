import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../domain/models/detection_result.dart';

// CropGuard brand green — matches AppColors.primary.
const _kGreen = PdfColor.fromInt(0xFF2E7D32);
const _kGreenLight = PdfColor.fromInt(0xFFE8F5E9);

class ScanReportPdfExporter {
  // ── Single scan report ────────────────────────────────────────────────────

  static Future<void> shareScanReport(DetectionResult scan) async {
    final pdf = pw.Document();

    final scanImageBytes = _tryReadImageBytes(scan.imagePath);
    final date = DateFormat('dd MMM yyyy  HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(scan.timestamp));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader('Scan Report', date),
            pw.SizedBox(height: 20),

            if (scanImageBytes != null) ...[
              pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Image(
                  pw.MemoryImage(scanImageBytes),
                  height: 180,
                  width: double.infinity,
                  fit: pw.BoxFit.cover,
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            _buildSectionTitle('Diagnosis'),
            pw.SizedBox(height: 8),
            _buildTable([
              ['Disease', scan.displayName],
              ['Crop', scan.cropType],
              ['Severity', scan.severity.toUpperCase()],
              ['Confidence', '${(scan.confidence * 100).toInt()}%'],
              ['Result', scan.isHealthy ? 'Healthy ✓' : 'Disease detected ✗'],
              ['Scanned on', date],
            ]),
            pw.SizedBox(height: 20),

            if (scan.cause.isNotEmpty) ...[
              _buildSectionTitle('Cause'),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _kGreenLight,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(scan.cause,
                    style: const pw.TextStyle(fontSize: 11)),
              ),
              pw.SizedBox(height: 20),
            ],

            if (scan.treatments.isNotEmpty) ...[
              _buildSectionTitle(
                  scan.isHealthy ? 'Crop Care Tips' : 'Treatment Steps'),
              pw.SizedBox(height: 6),
              ...scan.treatments.asMap().entries.map(
                    (e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 18,
                            height: 18,
                            margin: const pw.EdgeInsets.only(right: 6, top: 1),
                            decoration: const pw.BoxDecoration(
                              color: _kGreen,
                              shape: pw.BoxShape.circle,
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text('${e.key + 1}',
                                style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Expanded(
                            child: pw.Text(e.value,
                                style: const pw.TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
              pw.SizedBox(height: 20),
            ],

            pw.Spacer(),
            _buildDisclaimer(),
          ],
        ),
      ),
    );

    await _saveAndShare(pdf, 'scan_report_${scan.id}.pdf',
        'CropGuard AI Scan Report');
  }

  // ── Monthly / batch summary report ────────────────────────────────────────

  static Future<void> shareMonthlyReport(
      List<DetectionResult> detections) async {
    if (detections.isEmpty) return;

    final pdf = pw.Document();

    final healthyCount = detections.where((d) => d.isHealthy).length;
    final diseasedCount = detections.length - healthyCount;
    final cropGroups = _groupByCrop(detections);
    final diseaseGroups = _groupByDisease(detections);
    final now = DateFormat('dd MMM yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader('Farm Health Summary', 'Generated $now'),
            pw.SizedBox(height: 20),

            _buildSectionTitle('Overview'),
            pw.SizedBox(height: 8),
            _buildTable([
              ['Total scans', '${detections.length}'],
              ['Healthy', '$healthyCount'],
              ['Diseased', '$diseasedCount'],
              [
                'Health rate',
                '${detections.isEmpty ? 0 : (healthyCount / detections.length * 100).toInt()}%'
              ],
            ]),
            pw.SizedBox(height: 20),

            if (cropGroups.isNotEmpty) ...[
              _buildSectionTitle('Scans by Crop'),
              pw.SizedBox(height: 8),
              _buildTable([
                ['Crop', 'Scans'],
                ...cropGroups.entries
                    .toList()
                    .map((e) => [e.key, '${e.value}']),
              ], hasHeader: true),
              pw.SizedBox(height: 20),
            ],

            if (diseaseGroups.isNotEmpty) ...[
              _buildSectionTitle('Detected Diseases'),
              pw.SizedBox(height: 8),
              _buildTable([
                ['Disease', 'Occurrences'],
                ...diseaseGroups.entries
                    .toList()
                    .map((e) => [e.key, '${e.value}']),
              ], hasHeader: true),
              pw.SizedBox(height: 20),
            ],

            pw.Spacer(),
            _buildDisclaimer(),
          ],
        ),
      ),
    );

    await _saveAndShare(
      pdf,
      'farm_summary_${DateTime.now().millisecondsSinceEpoch}.pdf',
      'CropGuard AI Farm Health Summary',
    );
  }

  // ── Shared PDF widgets ────────────────────────────────────────────────────

  static pw.Widget _buildHeader(String title, String subtitle) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: pw.BoxDecoration(
        color: _kGreen,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CropGuard AI',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: _kGreen,
      ),
    );
  }

  /// Builds a two-column key-value table. Pass [hasHeader] = true if the first
  /// row should be rendered as a bold header row.
  static pw.Widget _buildTable(List<List<String>> rows,
      {bool hasHeader = false}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
      },
      children: rows.asMap().entries.map((entry) {
        final isHeader = hasHeader && entry.key == 0;
        final isEven = entry.key.isEven;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isHeader
                ? _kGreen
                : (isEven ? PdfColors.white : _kGreenLight),
          ),
          children: entry.value.map((cell) {
            return pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: pw.Text(
                cell,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: isHeader ? PdfColors.white : PdfColors.black,
                  fontWeight: isHeader ? pw.FontWeight.bold : null,
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildDisclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: _kGreen, width: 3),
        ),
      ),
      child: pw.Text(
        'Disclaimer: CropGuard AI provides guidance based on AI analysis. '
        'Always consult a qualified agricultural expert before acting on '
        'these results.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  // ── File helpers ──────────────────────────────────────────────────────────

  static Uint8List? _tryReadImageBytes(String path) {
    if (path.isEmpty) return null;
    try {
      final file = File(path);
      if (file.existsSync()) return file.readAsBytesSync();
    } catch (_) {}
    return null;
  }

  static Future<void> _saveAndShare(
      pw.Document pdf, String filename, String subject) async {
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: subject));
  }

  // ── Data grouping helpers ─────────────────────────────────────────────────

  static Map<String, int> _groupByCrop(List<DetectionResult> detections) {
    final map = <String, int>{};
    for (final d in detections) {
      map[d.cropType] = (map[d.cropType] ?? 0) + 1;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  static Map<String, int> _groupByDisease(List<DetectionResult> detections) {
    final map = <String, int>{};
    for (final d in detections.where((d) => !d.isHealthy)) {
      map[d.displayName] = (map[d.displayName] ?? 0) + 1;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }
}
