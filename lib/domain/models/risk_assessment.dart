enum RiskLevel {
  none,
  low,
  moderate,
  high,
}

enum RiskConfidence {
  insufficientData,
  low,
  medium,
  high,
}

class RiskAssessment {
  final String? region;
  final double latitude;
  final double longitude;
  final String? cropType;
  final RiskLevel riskLevel;
  final RiskConfidence confidence;
  final List<String> contributingFactors;
  final DateTime computedAt;

  RiskAssessment({
    this.region,
    required this.latitude,
    required this.longitude,
    this.cropType,
    required this.riskLevel,
    required this.confidence,
    required this.contributingFactors,
    required this.computedAt,
  });

  bool get isInsufficientData => confidence == RiskConfidence.insufficientData;

  Map<String, dynamic> toJson() => {
        'region': region,
        'latitude': latitude,
        'longitude': longitude,
        'cropType': cropType,
        'riskLevel': riskLevel.name,
        'confidence': confidence.name,
        'contributingFactors': contributingFactors,
        'computedAt': computedAt.toIso8601String(),
      };

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    return RiskAssessment(
      region: json['region'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      cropType: json['cropType'] as String?,
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == json['riskLevel'],
        orElse: () => RiskLevel.none,
      ),
      confidence: RiskConfidence.values.firstWhere(
        (e) => e.name == json['confidence'],
        orElse: () => RiskConfidence.insufficientData,
      ),
      contributingFactors: List<String>.from(json['contributingFactors'] ?? []),
      computedAt: json['computedAt'] != null
          ? DateTime.parse(json['computedAt'] as String)
          : DateTime.now(),
    );
  }
}
