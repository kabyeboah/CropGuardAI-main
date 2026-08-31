class ReporterTrustStats {
  final int totalSubmittedReports;
  final int verifiedReportsCount;
  final int verificationsGivenCount;
  final int trustScore;
  final String reputationBadgeTitle;

  const ReporterTrustStats({
    this.totalSubmittedReports = 0,
    this.verifiedReportsCount = 0,
    this.verificationsGivenCount = 0,
    this.trustScore = 0,
    this.reputationBadgeTitle = '🌱 Novice Observer',
  });

  factory ReporterTrustStats.calculate({
    required int totalSubmitted,
    required int verifiedReports,
    required int verificationsGiven,
    int refutedReports = 0,
  }) {
    final score = ((verifiedReports * 10) +
            (verificationsGiven * 2) -
            (refutedReports * 5))
        .clamp(0, 9999);

    String badge;
    if (score >= 150) {
      badge = '🏅 Master Guardian';
    } else if (score >= 75) {
      badge = '🛡️ Trusted Sentinel';
    } else if (score >= 25) {
      badge = '🌿 Field Reporter';
    } else {
      badge = '🌱 Novice Observer';
    }

    return ReporterTrustStats(
      totalSubmittedReports: totalSubmitted,
      verifiedReportsCount: verifiedReports,
      verificationsGivenCount: verificationsGiven,
      trustScore: score,
      reputationBadgeTitle: badge,
    );
  }

  Map<String, dynamic> toMap() => {
        'totalSubmittedReports': totalSubmittedReports,
        'verifiedReportsCount': verifiedReportsCount,
        'verificationsGivenCount': verificationsGivenCount,
        'trustScore': trustScore,
        'reputationBadgeTitle': reputationBadgeTitle,
      };

  factory ReporterTrustStats.fromMap(Map<String, dynamic> map) {
    return ReporterTrustStats(
      totalSubmittedReports: map['totalSubmittedReports'] ?? 0,
      verifiedReportsCount: map['verifiedReportsCount'] ?? 0,
      verificationsGivenCount: map['verificationsGivenCount'] ?? 0,
      trustScore: map['trustScore'] ?? 0,
      reputationBadgeTitle: map['reputationBadgeTitle'] ?? '🌱 Novice Observer',
    );
  }
}
