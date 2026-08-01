import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/location_helper.dart';
import '../../../../domain/models/risk_assessment.dart';
import '../../../../domain/usecases/risk/get_risk_assessment_usecase.dart';
import '../../../components/cropguard_card.dart';

class RiskCard extends StatefulWidget {
  final String? cropType;
  final GeoPoint? location;
  final GetRiskAssessmentUseCase? getRiskAssessmentUseCase;

  const RiskCard({
    super.key,
    this.cropType,
    this.location,
    this.getRiskAssessmentUseCase,
  });

  @override
  State<RiskCard> createState() => _RiskCardState();
}

class _RiskCardState extends State<RiskCard> {
  late final GetRiskAssessmentUseCase _useCase;
  bool _loading = true;
  RiskAssessment? _assessment;
  String? _error;

  @override
  void initState() {
    super.initState();
    _useCase = widget.getRiskAssessmentUseCase ?? sl<GetRiskAssessmentUseCase>();
    _fetchRisk();
  }

  @override
  void didUpdateWidget(covariant RiskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cropType != widget.cropType ||
        oldWidget.location?.latitude != widget.location?.latitude ||
        oldWidget.location?.longitude != widget.location?.longitude) {
      _fetchRisk();
    }
  }

  Future<void> _fetchRisk() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final point = widget.location ?? await LocationHelper.currentOrFallback();
      final result = await _useCase(
        lat: point.latitude,
        lon: point.longitude,
        cropType: widget.cropType,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _assessment = result.data;
          _loading = false;
        });
      } else {
        setState(() {
          _error = result.failure?.message ?? 'Failed to load risk forecast';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    if (_loading) {
      return CropGuardCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.riskForecastLoading,
                style: TextStyle(color: colors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _assessment == null) {
      return const SizedBox.shrink();
    }

    final assessment = _assessment!;
    final (Color badgeColor, String levelText) = switch (assessment.riskLevel) {
      RiskLevel.high => (colors.diseaseRed, l10n.riskLevelHigh),
      RiskLevel.moderate => (colors.warning, l10n.riskLevelModerate),
      RiskLevel.low => (colors.healthy, l10n.riskLevelLow),
      RiskLevel.none => (colors.muted, l10n.riskLevelNone),
    };

    final confidenceText = switch (assessment.confidence) {
      RiskConfidence.high => l10n.confidenceHigh,
      RiskConfidence.medium => l10n.confidenceMedium,
      RiskConfidence.low => l10n.confidenceLow,
      RiskConfidence.insufficientData => l10n.confidenceInsufficientData,
    };

    return CropGuardCard(
      onTap: () {
        final queryParams = <String, String>{};
        if (assessment.cropType != null && assessment.cropType!.isNotEmpty) {
          queryParams['crop'] = assessment.cropType!;
        }
        if (assessment.region != null && assessment.region!.isNotEmpty) {
          queryParams['region'] = assessment.region!;
        }
        final uri = Uri(path: '/outbreak_map', queryParameters: queryParams.isEmpty ? null : queryParams);
        context.push(uri.toString());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: assessment.riskLevel == RiskLevel.high
                    ? colors.diseaseRed
                    : colors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.riskForecastTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (assessment.region != null)
                      Text(
                        '${assessment.region}${assessment.cropType != null ? " • ${assessment.cropType}" : ""}',
                        style: TextStyle(color: colors.muted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  levelText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (assessment.isInsufficientData) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colors.muted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.riskInsufficientDataMsg,
                      style: TextStyle(color: colors.onBackgroundSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...assessment.contributingFactors.map(
              (factor) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 6),
                      child: Icon(Icons.circle, size: 6, color: colors.muted),
                    ),
                    Expanded(
                      child: Text(
                        factor,
                        style: TextStyle(
                          color: colors.onBackgroundSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n.confidenceLabel}: $confidenceText',
                style: TextStyle(color: colors.muted, fontSize: 11),
              ),
              Row(
                children: [
                  Text(
                    l10n.viewRiskMap,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: colors.primary),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
