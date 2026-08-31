/// Diagnostic analysis result returned from Gemini 1.5 Flash Cloud AI vision.
class CloudAiAnalysisResult {
  final String label;
  final double confidence;
  final bool isHealthy;
  final List<String> symptoms;
  final String rootCause;
  final List<String> organicRemedies;
  final List<String> preventionTips;
  final String? rawReasoning;
  final bool isFallback;

  const CloudAiAnalysisResult({
    required this.label,
    required this.confidence,
    required this.isHealthy,
    this.symptoms = const [],
    this.rootCause = '',
    this.organicRemedies = const [],
    this.preventionTips = const [],
    this.rawReasoning,
    this.isFallback = false,
  });

  /// Factory constructor to create a result from structured Gemini JSON output.
  factory CloudAiAnalysisResult.fromJson(Map<String, dynamic> json) {
    return CloudAiAnalysisResult(
      label: json['label'] as String? ?? 'Unknown Crop Disease',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
      isHealthy: json['isHealthy'] as bool? ?? false,
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rootCause: json['rootCause'] as String? ?? '',
      organicRemedies: (json['organicRemedies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      preventionTips: (json['preventionTips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rawReasoning: json['rawReasoning'] as String?,
      isFallback: json['isFallback'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'isHealthy': isHealthy,
        'symptoms': symptoms,
        'rootCause': rootCause,
        'organicRemedies': organicRemedies,
        'preventionTips': preventionTips,
        'rawReasoning': rawReasoning,
        'isFallback': isFallback,
      };
}
