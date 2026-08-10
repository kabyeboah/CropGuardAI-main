import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../components/confidence_bar.dart';
import '../../components/cropguard_card.dart';
import '../../components/primary_button.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/repositories/i_community_repository.dart';
import '../../../data/remote/firebase_auth_service.dart';
import '../../../data/ml/crop_disease_classifier.dart';
import '../scanner/scanner_provider.dart';

// ─── How many extra angles can be added ──────────────────────────────────────
const int _kMaxAngles = 3; // total shots including the first one

class LowConfidenceScreen extends StatefulWidget {
  final double confidence;
  final String imagePath;
  /// Top-3 candidates from the model on the initial scan.  Empty on fallback.
  final List<TopCandidate> topCandidates;

  const LowConfidenceScreen({
    super.key,
    required this.confidence,
    required this.imagePath,
    this.topCandidates = const [],
  });

  @override
  State<LowConfidenceScreen> createState() => _LowConfidenceScreenState();
}

class _LowConfidenceScreenState extends State<LowConfidenceScreen> {
  bool _reportSent = false;

  // Multi-angle retry state
  late List<double> _allConfidences;
  late List<List<TopCandidate>> _allPhotosCandidates;
  late List<TopCandidate> _mergedCandidates;
  int _anglesCaptured = 1; // starts at 1 (the initial scan already happened)
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _allConfidences = [widget.confidence];
    _allPhotosCandidates = [List<TopCandidate>.from(widget.topCandidates)];
    _recomputeSoftVotingCandidates();
  }

  void _recomputeSoftVotingCandidates() {
    final Map<String, double> labelSumMap = {};
    for (final photoCandidates in _allPhotosCandidates) {
      for (final c in photoCandidates) {
        labelSumMap[c.label] = (labelSumMap[c.label] ?? 0.0) + c.confidence;
      }
    }
    final int n = _allPhotosCandidates.length;
    if (n == 0 || labelSumMap.isEmpty) {
      _mergedCandidates = List<TopCandidate>.from(widget.topCandidates);
      return;
    }
    final List<TopCandidate> averaged = labelSumMap.entries.map((e) {
      return (label: e.key, confidence: e.value / n);
    }).toList();
    averaged.sort((a, b) => b.confidence.compareTo(a.confidence));
    _mergedCandidates = averaged.take(3).toList();
  }

  double get _averageConfidence =>
      _allConfidences.reduce((a, b) => a + b) / _allConfidences.length;

  bool get _canAddAngle => _anglesCaptured < _kMaxAngles;

  // ── Multi-angle capture ───────────────────────────────────────────────────

  Future<void> _captureAdditionalAngle() async {
    if (!_canAddAngle || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null || !mounted) {
        setState(() => _isCapturing = false);
        return;
      }

      final scannerProvider = context.read<ScannerProvider>();
      final result = await scannerProvider.classifyOnly(file.path);

      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.analysisFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isCapturing = false);
        return;
      }

      setState(() {
        _allConfidences.add(result.confidence);
        _allPhotosCandidates.add(List<TopCandidate>.from(result.topCandidates));
        _anglesCaptured++;
        _isCapturing = false;

        _recomputeSoftVotingCandidates();
      });

      // If averaged confidence now clears the threshold, graduate to full result.
      // We need to do a full analyseAndSave with the latest image so the result
      // is persisted to history properly.
      if (_averageConfidence >= CropDiseaseClassifier.confidenceThreshold) {
        if (!mounted) return;
        final detection =
            await context.read<ScannerProvider>().analyseAndSave(file.path);
        if (!mounted) return;
        if (detection != null) {
          context.replace('/result/${detection.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.analysisFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isCapturing = false);
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final avgConfidence = _averageConfidence;
    final pct = (avgConfidence * 100).toInt();

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/scanner');
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.lowConfidence,
          foregroundColor: Colors.white,
          title: Text(context.l10n.lowConfidenceTitle,
              style: const TextStyle(color: Colors.white)),
          leading: BackButton(
            color: Colors.white,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/scanner');
              }
            },
          ),
        ),
        backgroundColor: colors.background,
        body: Column(
          children: [
            // Image preview (darkened overlay)
            if (File(widget.imagePath).existsSync())
              SizedBox(
                height: 160,
                width: double.infinity,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.4), BlendMode.srcOver),
                  child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.help_outline,
                        size: 56, color: colors.lowConfidence),
                    const SizedBox(height: 16),

                    // ── Main confidence card ────────────────────────────────
                    CropGuardCard(
                      backgroundColor: colors.lowConfidenceBg,
                      borderColor: colors.lowConfidence,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.lowConfidenceResultTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: colors.lowConfidence)),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.lowConfidenceExplanation(pct),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          ConfidenceBar(
                            confidence: avgConfidence,
                            color: colors.lowConfidence,
                          ),
                          // Angle progress pill — only once a retry has been done
                          if (_anglesCaptured > 1) ...[
                            const SizedBox(height: 10),
                            _AnglePill(
                              captured: _anglesCaptured,
                              total: _kMaxAngles,
                              color: colors.lowConfidence,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Top-3 candidates card ───────────────────────────────
                    if (_mergedCandidates.isNotEmpty)
                      _TopCandidatesCard(
                        candidates: _mergedCandidates,
                        colors: colors,
                      ),

                    const SizedBox(height: 16),

                    Text(
                      context.l10n.lowConfidenceTips,
                      style: TextStyle(
                          color: colors.onBackgroundSecondary,
                          fontSize: 14,
                          height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // ── Multi-angle retry button ────────────────────────────
                    if (_canAddAngle)
                      PrimaryButton(
                        text: _isCapturing
                            ? context.l10n.analysing
                            : _anglesCaptured == 1
                                ? context.l10n.addAnotherAngle
                                : context.l10n.addAngle(
                                    _anglesCaptured + 1, _kMaxAngles),
                        icon: _isCapturing
                            ? Icons.hourglass_top
                            : Icons.add_a_photo,
                        onPressed: _isCapturing ? null : _captureAdditionalAngle,
                      )
                    else
                      // All angles used — simple restart to scanner
                      PrimaryButton(
                        text: context.l10n.tryAgain,
                        icon: Icons.camera_alt,
                        onPressed: () => context.go('/scanner'),
                      ),

                    const SizedBox(height: 12),

                    // ── Community / fallback buttons ────────────────────────
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
                    const SizedBox(height: 12),

                    if (!_reportSent)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.feedback_outlined, size: 20),
                        label: Text(context.l10n.cropNotInList),
                        onPressed: () => _showReportDialog(context),
                      )
                    else
                      // ── Post-report: loop-closing link ──────────────────
                      _ReportSentBanner(onViewSubmissions: () {
                        context.push('/submissions');
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Report dialog ────────────────────────────────────────────────────────

  void _showReportDialog(BuildContext context) {
    final cropController = TextEditingController();
    final symptomsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.reportMissingCropTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.reportMissingCropDesc),
            const SizedBox(height: 16),
            TextField(
              controller: cropController,
              decoration: InputDecoration(
                labelText: context.l10n.cropNameSimpleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symptomsController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.l10n.observedSymptomsLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              final crop = cropController.text;
              final symptoms = symptomsController.text;
              Navigator.pop(ctx);

              final messenger = ScaffoldMessenger.of(context);
              final failMsg = context.l10n.submitReportFailed;
              final uid = sl<FirebaseAuthService>().currentUserId;
              if (uid.isEmpty) {
                messenger
                    .showSnackBar(SnackBar(content: Text(failMsg)));
                return;
              }
              final res =
                  await sl<ICommunityRepository>().submitCropNotFound(
                userId: uid,
                suggestedCrop: crop,
                observedSymptoms: symptoms,
                imagePath: widget.imagePath,
              );
              res.fold(
                (_) {
                  if (mounted) {
                    setState(() => _reportSent = true);
                  }
                },
                (_) {
                  // Surface the failure so the user can retry instead of the
                  // report silently disappearing.
                  messenger
                      .showSnackBar(SnackBar(content: Text(failMsg)));
                },
              );
            },
            child: Text(context.l10n.submit),
          ),
        ],
      ),
    ).then((_) {
      cropController.dispose();
      symptomsController.dispose();
    });
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

/// Small pill showing how many angles have been captured out of the max.
class _AnglePill extends StatelessWidget {
  final int captured;
  final int total;
  final Color color;

  const _AnglePill({
    required this.captured,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.camera_alt, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          context.l10n.anglesCapturePill(captured, total),
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Card that shows the model's top-3 guesses with mini confidence bars.
class _TopCandidatesCard extends StatelessWidget {
  final List<TopCandidate> candidates;
  final CropColors colors;

  const _TopCandidatesCard({
    required this.candidates,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return CropGuardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_rounded, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                context.l10n.topGuesses,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...candidates.asMap().entries.map((entry) {
            final isTop = entry.key == 0;
            final c = entry.value;
            final pct = (c.confidence * 100).toInt();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isTop)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.star_rounded,
                              size: 14, color: colors.lowConfidence),
                        ),
                      Expanded(
                        child: Text(
                          c.label.replaceAll('_', ' '),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: isTop
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 12,
                          color: isTop
                              ? colors.lowConfidence
                              : colors.onBackgroundSecondary,
                          fontWeight: isTop
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: c.confidence,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isTop
                            ? colors.lowConfidence
                            : colors.primary.withValues(alpha: 0.55),
                      ),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Confirmation banner shown after a "crop not in list" report is submitted.
/// Provides a direct link to My Submissions so the loop is visibly closed.
class _ReportSentBanner extends StatelessWidget {
  final VoidCallback onViewSubmissions;

  const _ReportSentBanner({required this.onViewSubmissions});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.reportSubmittedThanks,
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.assignment_turned_in_outlined,
                  size: 16),
              label: Text(
                context.l10n.viewMySubmissions,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: onViewSubmissions,
            ),
          ),
        ],
      ),
    );
  }
}
