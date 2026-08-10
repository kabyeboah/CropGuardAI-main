import '../../../core/utils/scan_severity.dart';
import '../../data/ml/crop_disease_classifier.dart';

/// Equivalent of DetectionResult.kt domain data class
class DetectionResult {
  final int id;
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

  const DetectionResult({
    this.id = 0,
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
  });

  DetectionResult copyWith({
    int? id,
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
  }) {
    return DetectionResult(
      id: id ?? this.id,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
    };
  }

  factory DetectionResult.fromMap(Map<String, dynamic> map) {
    return DetectionResult(
      id: map['id'] as int? ?? 0,
      userId: map['userId'] as String? ?? '',
      imagePath: map['imagePath'] as String? ?? '',
      diseaseLabel: map['diseaseLabel'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      severity: map['severity'] as String? ?? ScanSeverity.unclear,
      isHealthy: (map['isHealthy'] as int? ?? 0) == 1,
      cropType: map['cropType'] as String? ?? '',
      cause: map['cause'] as String? ?? '',
      treatments: (map['treatments'] as String? ?? '').split('||').where((s) => s.isNotEmpty).toList(),
      timestamp: map['timestamp'] as int? ?? 0,
      isDegraded: (map['isDegraded'] as int? ?? 0) == 1,
    );
  }
}
