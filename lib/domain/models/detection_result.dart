import 'dart:convert';

import '../../../core/utils/scan_severity.dart';
import '../../data/ml/crop_disease_classifier.dart';

/// Equivalent of DetectionResult.kt domain data class
class DetectionResult {
  final int id;
  final String remoteId;
  final String userId;
  final String imagePath;
  final String diseaseLabel;
  final String displayName;
  final double confidence;
  final String severity;
  final bool isHealthy;
  final String cropType;
  final String cause;
  final List<String> treatments;
  final int timestamp; // milliseconds since epoch
  // True when this result came from the low-confidence / engine-unavailable
  // fallback rather than a genuine model prediction. History and any other
  // display surface must badge these clearly instead of showing them as a
  // confident diagnosis.
  final bool isDegraded;
  final List<TopCandidate> topCandidates;
  final String? modelVersion;
  final bool isSynced;
  final int? syncedAt;

  const DetectionResult({
    this.id = 0,
    this.remoteId = '',
    this.userId = '',
    required this.imagePath,
    required this.diseaseLabel,
    required this.displayName,
    required this.confidence,
    this.severity = ScanSeverity.unclear,
    required this.isHealthy,
    required this.cropType,
    required this.cause,
    required this.treatments,
    required this.timestamp,
    this.isDegraded = false,
    this.topCandidates = const [],
    this.modelVersion,
    this.isSynced = false,
    this.syncedAt,
  });

  DetectionResult copyWith({
    int? id,
    String? remoteId,
    String? userId,
    String? imagePath,
    String? diseaseLabel,
    String? displayName,
    double? confidence,
    String? severity,
    bool? isHealthy,
    String? cropType,
    String? cause,
    List<String>? treatments,
    int? timestamp,
    bool? isDegraded,
    List<TopCandidate>? topCandidates,
    String? modelVersion,
    bool? isSynced,
    int? syncedAt,
  }) {
    return DetectionResult(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      userId: userId ?? this.userId,
      imagePath: imagePath ?? this.imagePath,
      diseaseLabel: diseaseLabel ?? this.diseaseLabel,
      displayName: displayName ?? this.displayName,
      confidence: confidence ?? this.confidence,
      severity: severity ?? this.severity,
      isHealthy: isHealthy ?? this.isHealthy,
      cropType: cropType ?? this.cropType,
      cause: cause ?? this.cause,
      treatments: treatments ?? this.treatments,
      timestamp: timestamp ?? this.timestamp,
      isDegraded: isDegraded ?? this.isDegraded,
      topCandidates: topCandidates ?? this.topCandidates,
      modelVersion: modelVersion ?? this.modelVersion,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remoteId': remoteId,
      'userId': userId,
      'imagePath': imagePath,
      'diseaseLabel': diseaseLabel,
      'displayName': displayName,
      'confidence': confidence,
      'severity': severity,
      'isHealthy': isHealthy ? 1 : 0,
      'cropType': cropType,
      'cause': cause,
      'treatments': treatments.join('||'),
      'timestamp': timestamp,
      'isDegraded': isDegraded ? 1 : 0,
      'topCandidates': jsonEncode(
        topCandidates
            .map((c) => {'label': c.label, 'confidence': c.confidence})
            .toList(),
      ),
      'modelVersion': modelVersion,
      'isSynced': isSynced ? 1 : 0,
      'syncedAt': syncedAt,
    };
  }

  factory DetectionResult.fromMap(Map<String, dynamic> map) {
    int? parseSyncedAt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return null;
    }

    List<TopCandidate> parseTopCandidates(dynamic raw) {
      if (raw == null || raw is! String || raw.isEmpty) {
        return const <TopCandidate>[];
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map<TopCandidate>((item) {
            final m = item as Map<String, dynamic>;
            return (
              label: m['label'] as String? ?? '',
              confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
            );
          }).toList();
        }
      } catch (_) {}
      return const <TopCandidate>[];
    }

    return DetectionResult(
      id: map['id'] as int? ?? 0,
      remoteId: map['remoteId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      imagePath: map['imagePath'] as String? ?? '',
      diseaseLabel: map['diseaseLabel'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      severity: map['severity'] as String? ?? ScanSeverity.unclear,
      isHealthy: (map['isHealthy'] as int? ?? 0) == 1,
      cropType: map['cropType'] as String? ?? '',
      cause: map['cause'] as String? ?? '',
      treatments: (map['treatments'] as String? ?? '')
          .split('||')
          .where((s) => s.isNotEmpty)
          .toList(),
      timestamp: map['timestamp'] as int? ?? 0,
      isDegraded: (map['isDegraded'] as int? ?? 0) == 1,
      topCandidates: parseTopCandidates(map['topCandidates']),
      modelVersion: map['modelVersion'] as String?,
      isSynced: (map['isSynced'] as int? ?? 0) == 1,
      syncedAt: parseSyncedAt(map['syncedAt']),
    );
  }
}
