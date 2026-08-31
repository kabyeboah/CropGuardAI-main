import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../domain/models/disease_risk.dart';
import '../../../components/cropguard_card.dart';

/// Shows a short, prioritised disease-risk outlook derived from the weather
/// forecast. Preventive counterpart to the reactive scanner — tells the farmer
/// what to watch for *before* damage appears.
class DiseaseRiskForecastWidget extends StatelessWidget {
  final List<DiseaseRisk> risks;

  const DiseaseRiskForecastWidget({super.key, required this.risks});

  static String diseaseName(AppLocalizations l10n, DiseaseRiskType type) =>
      switch (type) {
        DiseaseRiskType.lateBlight => l10n.riskNameLateBlight,
        DiseaseRiskType.earlyBlight => l10n.riskNameEarlyBlight,
        DiseaseRiskType.blackPod => l10n.riskNameBlackPod,
        DiseaseRiskType.leafBlightRust => l10n.riskNameLeafBlightRust,
        DiseaseRiskType.riceBlast => l10n.riskNameRiceBlast,
      };

  static String cropName(AppLocalizations l10n, DiseaseRiskType type) =>
      switch (type) {
        DiseaseRiskType.lateBlight => l10n.cropTomato,
        DiseaseRiskType.earlyBlight => l10n.cropTomato,
        DiseaseRiskType.blackPod => l10n.cropCocoa,
        DiseaseRiskType.leafBlightRust => l10n.cropMaize,
        DiseaseRiskType.riceBlast => l10n.cropRice,
      };

  static String reason(AppLocalizations l10n, DiseaseRisk r) =>
      switch (r.type) {
        DiseaseRiskType.lateBlight =>
          l10n.riskReasonLateBlight(r.humidity, r.temp),
        DiseaseRiskType.earlyBlight =>
          l10n.riskReasonEarlyBlight(r.humidity, r.temp),
        DiseaseRiskType.blackPod => l10n.riskReasonBlackPod(r.humidity),
        DiseaseRiskType.leafBlightRust =>
          l10n.riskReasonLeafBlightRust(r.humidity, r.temp),
        DiseaseRiskType.riceBlast => l10n.riskReasonRiceBlast(r.temp),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    if (risks.isEmpty) {
      return CropGuardCard(
        backgroundColor: colors.healthyBg,
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: colors.healthy, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.diseaseRiskLowMessage,
                style: TextStyle(
                  color: colors.onBackgroundSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return CropGuardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined,
                  color: colors.diseaseRed, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.diseaseRiskWeekTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.diseaseRiskWeekSubtitle,
            style: TextStyle(color: colors.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...risks.map((r) => _RiskRow(risk: r)),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  final DiseaseRisk risk;

  const _RiskRow({required this.risk});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final (Color tint, String label) = switch (risk.level) {
      RiskLevel.high => (colors.diseaseRed, l10n.riskLevelHigh),
      RiskLevel.moderate => (colors.warning, l10n.riskLevelModerate),
      RiskLevel.low => (colors.healthy, l10n.riskLevelLow),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${DiseaseRiskForecastWidget.diseaseName(l10n, risk.type)}'
                        ' • ${DiseaseRiskForecastWidget.cropName(l10n, risk.type)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: tint,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  DiseaseRiskForecastWidget.reason(l10n, risk),
                  style: TextStyle(
                    color: colors.onBackgroundSecondary,
                    fontSize: 12,
                  ),
                ),
                if (risk.hasNearbyOutbreak) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFDC2626), size: 14),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Active verified outbreak reported in your region! Take precautions.',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
