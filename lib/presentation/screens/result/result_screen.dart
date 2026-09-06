import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../components/confidence_bar.dart';
import '../../components/cropguard_card.dart';
import '../../components/primary_button.dart';
import '../../components/section_label.dart';
import '../../components/severity_badge.dart';
import '../../../data/ml/disease_info.dart';
import '../../../data/remote/supabase_auth_service.dart';
import '../../../data/remote/gemini_cloud_ai_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/scan_report_pdf_exporter.dart';
import '../../../core/utils/tts_manager.dart';
import '../../../core/utils/scan_severity.dart';
import '../../../domain/models/detection_result.dart';
import '../outbreak_map/outbreak_map_screen.dart';
import '../treatment_tracker/treatment_tracker_provider.dart';
import 'result_provider.dart';
import '../../../core/utils/screen_security_helper.dart';

/// Equivalent of ResultScreen.kt
class ResultScreen extends StatefulWidget {
  final int detectionId;

  const ResultScreen({super.key, required this.detectionId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<String> _allLabels = [];
  bool _didSpeakResult = false;
  String? _selectedAlternativeLabel;

  @override
  void initState() {
    super.initState();
    _allLabels = DiseaseDatabase.getAllLabels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ResultProvider>().load(widget.detectionId);
    });
  }

  /// Maps the scanner's [ScanSeverity] vocabulary to the outbreak map's
  /// low/medium/high scale.
  String _outbreakSeverity(String scanSeverity) {
    switch (scanSeverity) {
      case ScanSeverity.severe:
        return 'high';
      case ScanSeverity.early:
        return 'low';
      case ScanSeverity.moderate:
      case ScanSeverity.warning:
      case ScanSeverity.diseased:
      default:
        return 'medium';
    }
  }

  void _speakResultOnce(DetectionResult result) {
    if (_didSpeakResult) return;
    _didSpeakResult = true;
    final lang = Localizations.localeOf(context).languageCode;
    TtsManager().speak(result.displayName, languageCode: lang);
  }

  bool _isVerifyingWithCloud = false;

  Future<void> _verifyWithCloudAi(DetectionResult result) async {
    if (_isVerifyingWithCloud) return;
    setState(() => _isVerifyingWithCloud = true);

    try {
      final geminiService = sl<GeminiCloudAiService>();
      final topCandidates = result.topCandidates.map((c) => c.label).toList();
      final cloudResult = await geminiService.analyzeCropImage(
        imagePath: result.imagePath,
        cropType: result.cropType,
        initialTopCandidates: topCandidates,
      );

      if (!mounted) return;
      setState(() => _isVerifyingWithCloud = false);

      unawaited(showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blueAccent),
              SizedBox(width: 8),
              Expanded(child: Text('Cloud AI Double-Check')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diagnosis: ${cloudResult.label}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Confidence: ${(cloudResult.confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold),
              ),
              if (cloudResult.rootCause.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Cause: ${cloudResult.rootCause}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (cloudResult.rawReasoning != null &&
                  cloudResult.rawReasoning!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  cloudResult.rawReasoning!,
                  style: const TextStyle(
                      fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifyingWithCloud = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cloud AI verification unavailable: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResultProvider>();
    final colors = context.colors;

    if (provider.isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    if (provider.result == null) {
      return Scaffold(
        body: Center(
            child: Text(provider.errorCode?.resolve(context.l10n) ??
                context.l10n.genericError)),
      );
    }

    final result = provider.result!;
    if (!_didSpeakResult) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _speakResultOnce(result);
      });
    }

    final activeLabel = _selectedAlternativeLabel ?? result.diseaseLabel;
    final activeInfo = DiseaseDatabase.getInfo(activeLabel);
    final activeDisplayName = activeInfo.displayName;
    final activeCropType = activeInfo.cropType;
    final activeSeverity = activeInfo.severity;
    final isHealthy = activeInfo.isHealthy;
    final activeCause = activeInfo.cause.isNotEmpty ? activeInfo.cause : result.cause;
    final activeTreatments = activeInfo.treatments.isNotEmpty ? activeInfo.treatments : result.treatments;

    double activeConfidence = result.confidence;
    for (final c in result.topCandidates) {
      if (c.label == activeLabel) {
        activeConfidence = c.confidence;
        break;
      }
    }

    final headerColor = isHealthy ? colors.healthy : colors.diseaseRed;
    final headerBg = isHealthy ? colors.healthyBg : colors.diseaseBg;

    return ScreenSecurityHelper(
      child: PopScope(
        canPop: Navigator.of(context).canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.go('/home');
        },
        child: Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: headerColor,
            foregroundColor: Colors.white,
            title: Text(
                isHealthy
                    ? context.l10n.healthyCropTitle
                    : context.l10n.diseaseDetectedTitle,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            leading: BackButton(
              color: Colors.white,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            actions: [
              IconButton(
                tooltip: 'Share Report',
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () async {
                  await ScanReportPdfExporter.shareScanReport(result);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                if (File(result.imagePath).existsSync())
                  Semantics(
                    label: 'Captured leaf image for $activeDisplayName',
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child:
                          Image.file(File(result.imagePath), fit: BoxFit.cover),
                    ),
                  )
                else
                  Container(
                    height: 220,
                    width: double.infinity,
                    color: colors.surface,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_camera_outlined,
                            size: 48, color: colors.muted),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.imageUnavailable,
                          style: TextStyle(
                              color: colors.onBackgroundSecondary,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                // Result header band
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: headerBg,
                  child: Row(
                    children: [
                      Semantics(
                        label: isHealthy
                            ? 'Status: Healthy crop'
                            : 'Status: Disease detected — $activeDisplayName',
                        excludeSemantics: true,
                        child: Icon(
                          isHealthy ? Icons.check_circle : Icons.warning_amber,
                          color: headerColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(activeDisplayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              color: headerColor,
                                              fontWeight: FontWeight.bold)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: headerColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: headerColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '${(activeConfidence * 100).toStringAsFixed(0)}% Match',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: headerColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(activeCropType,
                                style: TextStyle(
                                    color: headerColor.withValues(alpha: 0.8),
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      Semantics(
                        label: 'Severity: $activeSeverity',
                        excludeSemantics: true,
                        child: SeverityBadge(severity: activeSeverity),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Read result aloud',
                        icon: const Icon(Icons.volume_up, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: headerColor.withValues(alpha: 0.3),
                        ),
                        onPressed: () {
                          final lang =
                              Localizations.localeOf(context).languageCode;
                          final treatments =
                              activeTreatments.take(3).join(". ");
                          final text = context.l10n.ttsResultSummary(
                            activeDisplayName,
                            activeSeverity,
                            treatments,
                          );
                          TtsManager().speak(text, languageCode: lang);
                        },
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Match & Differential Confidence Card (Highest Percentage Front & Center)
                      CropGuardCard(
                        backgroundColor: colors.surface,
                        borderColor: headerColor.withValues(alpha: 0.35),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      activeConfidence >= 0.65
                                          ? Icons.verified
                                          : Icons.auto_graph_rounded,
                                      size: 18,
                                      color: headerColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      activeConfidence >= 0.65
                                          ? 'High Confidence Match'
                                          : activeConfidence >= 0.40
                                              ? 'Moderate Match (Top Prediction)'
                                              : 'Preliminary Match (Highest Model Probability)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: colors.onBackground,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${(activeConfidence * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: headerColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ConfidenceBar(
                              confidence: activeConfidence,
                              color: headerColor,
                            ),
                            if (result.topCandidates.length > 1) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Compare Candidate Differentials (Tap to view):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onBackgroundSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: result.topCandidates.map((candidate) {
                                  final isCurrent = candidate.label == activeLabel;
                                  final candPct = (candidate.confidence * 100).toStringAsFixed(0);
                                  final candName = candidate.label.replaceAll('_', ' ');
                                  return ChoiceChip(
                                    selected: isCurrent,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedAlternativeLabel = selected ? candidate.label : null;
                                      });
                                    },
                                    backgroundColor: colors.primary.withValues(alpha: 0.06),
                                    selectedColor: colors.primary.withValues(alpha: 0.2),
                                    label: Text('$candName ($candPct%)'),
                                    labelStyle: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                      color: isCurrent ? colors.primary : colors.onBackground,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (activeConfidence < 0.65) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.primary,
                                    side: BorderSide(color: colors.primary),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: _isVerifyingWithCloud
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome, size: 16),
                                  label: Text(
                                    _isVerifyingWithCloud
                                        ? 'Consulting Gemini Cloud AI...'
                                        : 'Double-Check with Gemini Cloud AI',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: _isVerifyingWithCloud
                                      ? null
                                      : () => _verifyWithCloudAi(result),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cause
                      if (!isHealthy && activeCause.isNotEmpty) ...[
                        SectionLabel(text: context.l10n.causeLabel),
                        const SizedBox(height: 8),
                        CropGuardCard(
                          child: Text(activeCause,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Treatments
                      if (activeTreatments.isNotEmpty) ...[
                        SectionLabel(
                            text: isHealthy
                                ? context.l10n.cropCareTips
                                : context.l10n.treatmentSteps),
                        const SizedBox(height: 8),
                        CropGuardCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...activeTreatments.asMap().entries.map((e) =>
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: headerColor.withValues(
                                                alpha: 0.15),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${e.key + 1}',
                                              style: TextStyle(
                                                  color: headerColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(e.value,
                                              style: Theme.of(context)
                                                  .textTheme.bodyMedium),
                                        ),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: colors.primary
                                          .withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.verified_outlined,
                                        size: 14, color: colors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Source / Basis: ${DiseaseDatabase.getInfo(activeLabel).sourceBasis}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isHealthy &&
                                  DiseaseDatabase.getInfo(result.diseaseLabel)
                                          .safetyPrecautions !=
                                      null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.health_and_safety_outlined,
                                        size: 14, color: colors.warning),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        DiseaseDatabase.getInfo(
                                                result.diseaseLabel)
                                            .safetyPrecautions!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.onBackgroundSecondary,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 14, color: colors.muted),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      context.l10n.treatmentAdvisoryDisclaimer,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onBackgroundSecondary,
                                        fontStyle: FontStyle.italic,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Spray Advisory
                      if (!isHealthy &&
                          (provider.sprayAdvisory.isNotEmpty ||
                              provider.sprayAdvisoryUnavailable)) ...[
                        SectionLabel(text: context.l10n.bestSprayWindow),
                        const SizedBox(height: 8),
                        CropGuardCard(
                          backgroundColor:
                              colors.primary.withValues(alpha: 0.05),
                          child: Row(
                            children: [
                              Icon(Icons.wb_sunny_outlined,
                                  color: colors.primary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  provider.sprayAdvisoryUnavailable
                                      ? context.l10n.sprayAdvisoryUnavailable
                                      : provider.sprayAdvisory,
                                  style: TextStyle(
                                    color: colors.onBackground,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Actions
                      if (!isHealthy) ...[
                        // Track Treatment CTA
                        _TrackTreatmentButton(
                          detectionId: result.id,
                          cropType: result.cropType,
                          diseaseName: result.displayName,
                          treatments: result.treatments,
                          severity: result.severity,
                        ),
                        const SizedBox(height: 10),
                        PrimaryButton(
                          text: context.l10n.requestExpertHelp,
                          icon: Icons.support_agent,
                          isLoading: provider.isRequestingExpert,
                          onPressed: provider.expertRequestSent
                              ? null
                              : () => _showExpertDialog(context, provider),
                        ),
                        const SizedBox(height: 10),
                        // Report this detection to the community outbreak map,
                        // carrying the CNN's disease + confidence + severity.
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: BorderSide(color: colors.diseaseRed),
                            foregroundColor: colors.diseaseRed,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add_location_alt, size: 18),
                          label: Text(context.l10n.reportToOutbreakMap,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => context.push(
                            '/outbreak_map',
                            extra: OutbreakReportPrefill(
                              disease: result.displayName,
                              confidence: result.confidence,
                              severity: _outbreakSeverity(result.severity),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      PrimaryButton(
                        text: context.l10n.scanAnotherCrop,
                        icon: Icons.camera_alt,
                        onPressed: () => context.go('/scanner'),
                      ),
                      const SizedBox(height: 10),

                      // Post to Community button - always visible
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: BorderSide(color: colors.primary),
                          foregroundColor: colors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.forum_outlined, size: 18),
                        label: Text(context.l10n.postToCommunity,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => context.push('/community'),
                      ),
                      const SizedBox(height: 10),

                      // Feedback
                      if (!provider.feedbackSent)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            side: BorderSide(color: colors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(Icons.feedback_outlined,
                              color: colors.muted, size: 16),
                          label: Text(context.l10n.feedbackPrompt,
                              style: TextStyle(
                                  color: colors.onBackgroundSecondary,
                                  fontSize: 13)),
                          onPressed: () =>
                              _showFeedbackDialog(context, provider),
                        ),
                      if (provider.feedbackSent)
                        Center(
                          child: Text(context.l10n.feedbackThanks,
                              style: TextStyle(
                                  color: colors.healthy, fontSize: 13)),
                        ),

                      const SizedBox(height: 10),

                      // Crop Not Found Feedback
                      if (!provider.cropNotFoundSent)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            side: BorderSide(color: colors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(Icons.help_center_outlined,
                              color: colors.muted, size: 16),
                          label: Text(context.l10n.cropNotFoundPrompt,
                              style: TextStyle(
                                  color: colors.onBackgroundSecondary,
                                  fontSize: 13)),
                          onPressed: () =>
                              _showCropNotFoundDialog(context, provider),
                        ),
                      if (provider.cropNotFoundSent)
                        Center(
                          child: Text(context.l10n.cropReportSubmitted,
                              style: TextStyle(
                                  color: colors.primary, fontSize: 13)),
                        ),

                      const SizedBox(height: 16),

                      // ── Persistent Scope Disclaimer (Task 3) ────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined,
                                size: 16, color: colors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'CropGuard identifies known crop leaf diseases from photos. It is not validated for other subjects and should not be the sole basis for treatment decisions.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onBackgroundSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showExpertDialog(
      BuildContext ctx, ResultProvider provider) async {
    final controller = TextEditingController();
    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: Text(ctx.l10n.requestExpertHelp),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.l10n.expertHelpDesc),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: ctx.l10n.expertHelpHint,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    return Text(
                      '${value.text.length}/500',
                      style: TextStyle(
                          color: value.text.length >= 500
                              ? Colors.red
                              : Colors.grey,
                          fontSize: 12),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(ctx.l10n.cancel)),
            ElevatedButton(
              onPressed: () async {
                final message = controller.text;
                Navigator.pop(dialogCtx);
                final messenger = ScaffoldMessenger.of(ctx);
                final failMsg = ctx.l10n.sendRequestFailed;
                final uid = sl<SupabaseAuthService>().currentUserId;
                if (uid.isEmpty) {
                  messenger.showSnackBar(SnackBar(content: Text(failMsg)));
                  return;
                }
                final sentMsg = ctx.l10n.expertRequestSentMsg;
                await provider.requestExpertHelp(userId: uid, message: message);
                messenger.showSnackBar(SnackBar(
                  content: Text(provider.expertRequestSent ? sentMsg : failMsg),
                ));
              },
              child: Text(ctx.l10n.send),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showFeedbackDialog(
      BuildContext ctx, ResultProvider provider) async {
    final controller = TextEditingController();
    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: Text(ctx.l10n.correctDiagnosisTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.l10n.correctDiagnosisDesc),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return _allLabels.where((String option) {
                    return option
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  controller.text = selection;
                },
                fieldViewBuilder:
                    (context, fieldController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: fieldController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: ctx.l10n.searchDiseaseLabel,
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.search),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(ctx.l10n.cancel)),
            ElevatedButton(
              onPressed: () async {
                final label = controller.text;
                Navigator.pop(dialogCtx);
                final messenger = ScaffoldMessenger.of(ctx);
                final failMsg = ctx.l10n.sendFeedbackFailed;
                final uid = sl<SupabaseAuthService>().currentUserId;
                if (uid.isEmpty) {
                  messenger.showSnackBar(SnackBar(content: Text(failMsg)));
                  return;
                }
                await provider.submitFeedback(
                    userId: uid, correctedLabel: label);
                if (!provider.feedbackSent) {
                  messenger.showSnackBar(SnackBar(content: Text(failMsg)));
                }
              },
              child: Text(ctx.l10n.submit),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showCropNotFoundDialog(
      BuildContext ctx, ResultProvider provider) async {
    final cropController = TextEditingController();
    final symptomsController = TextEditingController();
    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: Text(context.l10n.reportMissingCropTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.reportMissingCropDescResult),
                const SizedBox(height: 16),
                TextField(
                  controller: cropController,
                  decoration: InputDecoration(
                    labelText: context.l10n.cropNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: symptomsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.l10n.symptomsObservedLabel,
                    hintText: context.l10n.symptomsHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(context.l10n.cancel)),
            ElevatedButton(
              onPressed: () async {
                final crop = cropController.text;
                final symptoms = symptomsController.text;
                Navigator.pop(dialogCtx);
                final messenger = ScaffoldMessenger.of(ctx);
                final failMsg = ctx.l10n.submitReportFailed;
                final uid = sl<SupabaseAuthService>().currentUserId;
                if (uid.isEmpty) {
                  messenger.showSnackBar(SnackBar(content: Text(failMsg)));
                  return;
                }
                await provider.submitCropNotFound(
                  userId: uid,
                  suggestedCrop: crop,
                  observedSymptoms: symptoms,
                );
                if (!provider.cropNotFoundSent) {
                  messenger.showSnackBar(SnackBar(content: Text(failMsg)));
                }
              },
              child: Text(context.l10n.submitReport),
            ),
          ],
        ),
      );
    } finally {
      cropController.dispose();
      symptomsController.dispose();
    }
  }
}

/// CTA button that pre-fills the treatment plan from the current detection
class _TrackTreatmentButton extends StatefulWidget {
  final int detectionId;
  final String cropType;
  final String diseaseName;
  final List<String> treatments;
  final String severity;

  const _TrackTreatmentButton({
    required this.detectionId,
    required this.cropType,
    required this.diseaseName,
    required this.treatments,
    required this.severity,
  });

  @override
  State<_TrackTreatmentButton> createState() => _TrackTreatmentButtonState();
}

class _TrackTreatmentButtonState extends State<_TrackTreatmentButton> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _track() async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
    try {
      await context.read<TreatmentTrackerProvider>().addFromDetection(
            detectionId: widget.detectionId,
            cropType: widget.cropType,
            diseaseName: widget.diseaseName,
            treatmentSteps: widget.treatments,
            severity: widget.severity,
          );
      if (mounted) {
        setState(() {
          _saving = false;
          _saved = true;
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) unawaited(context.push('/treatment_tracker'));
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _saved ? colors.healthy : colors.primary.withValues(alpha: 0.9),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                _saved ? Icons.check_circle : Icons.assignment_add,
                size: 18,
              ),
        label: Text(
          _saved ? 'Treatment Plan Saved!' : 'Track Treatment Plan',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: _track,
      ),
    );
  }
}
