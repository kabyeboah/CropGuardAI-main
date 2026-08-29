import 'dart:async';
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
import '../../../data/remote/gemini_cloud_ai_service.dart';
import '../../../domain/models/community_post.dart';
import '../../../domain/models/disease_risk.dart';
import '../../../core/utils/risk_weighted_classifier.dart';
import '../../../core/utils/agri_weather_utils.dart';
import '../../../data/ml/crop_disease_classifier.dart';
import '../home/home_provider.dart';
import '../scanner/scanner_provider.dart';

// ─── How many extra angles can be added ──────────────────────────────────────
const int _kMaxAngles = 3; // total shots including the first one

class LowConfidenceScreen extends StatefulWidget {
  final double confidence;
  final String imagePath;
  /// Top-3 candidates from the model on the initial scan.  Empty on fallback.
  final List<TopCandidate> topCandidates;
  final List<DiseaseRisk>? regionalRisks;

  const LowConfidenceScreen({
    super.key,
    required this.confidence,
    required this.imagePath,
    this.topCandidates = const [],
    this.regionalRisks,
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
  bool _isCloudAnalyzing = false;
  bool _isEscalating = false;
  final Set<String> _selectedSymptoms = {};

  @override
  void initState() {
    super.initState();
    _allConfidences = [widget.confidence];
    final initialCandidates = widget.topCandidates.isNotEmpty
        ? List<TopCandidate>.from(widget.topCandidates)
        : _getFallbackTopCandidates();

    List<DiseaseRisk> risks = widget.regionalRisks ?? const [];
    if (risks.isEmpty) {
      try {
        final homeProvider = context.read<HomeProvider>();
        if (homeProvider.weeklyRisks.isNotEmpty) {
          risks = homeProvider.weeklyRisks;
        } else if (homeProvider.weather != null && homeProvider.weather!.daily.isNotEmpty) {
          final region = homeProvider.weather!.latitude > 8.0 ? 'North' : 'South';
          risks = AgriWeatherUtils.assessWeeklyRisks(
            homeProvider.weather!.daily,
            outbreaks: homeProvider.outbreaks,
            region: region,
          );
        }
      } catch (_) {}
    }

    // Regional Outbreak Risk-Weighted adjustment
    final regionalRiskAdjusted = RiskWeightedClassifier.adjustCandidatesWithRegionalRisk(
      candidates: initialCandidates,
      regionalRisks: risks,
    );

    _allPhotosCandidates = [regionalRiskAdjusted];
    _recomputeSoftVotingCandidates();
  }

  List<TopCandidate> _getFallbackTopCandidates() {
    final conf = widget.confidence > 0 ? widget.confidence : 0.0;
    return [
      (label: 'Unidentified', confidence: conf),
    ];
  }

  void _recomputeSoftVotingCandidates() {
    final fallback = widget.topCandidates.isNotEmpty
        ? List<TopCandidate>.from(widget.topCandidates)
        : _getFallbackTopCandidates();
    _mergedCandidates = CropDiseaseClassifier.computeSoftVotingCandidates(
      _allPhotosCandidates,
      fallbackCandidates: fallback,
    );
  }

  double get _averageConfidence =>
      _allConfidences.reduce((a, b) => a + b) / _allConfidences.length;

  bool get _canAddAngle => _anglesCaptured < _kMaxAngles;

  // ── Multi-angle retry ───────────────────────────────────────────────────

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

      if (_averageConfidence >= CropDiseaseClassifier.confidenceThreshold) {
        if (!mounted) return;
        final topLabel = _mergedCandidates.isNotEmpty
            ? _mergedCandidates.first.label
            : result.label;
        final detection = await context.read<ScannerProvider>().saveMergedScan(
              imagePath: widget.imagePath,
              diseaseLabel: topLabel,
              confidence: _averageConfidence,
              topCandidates: _mergedCandidates,
              isDegraded: false,
            );
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

  // ── Gemini Cloud AI Multimodal Fallback ───────────────────────────────────

  Future<void> _requestCloudAiAnalysis() async {
    if (_isCloudAnalyzing) return;
    setState(() => _isCloudAnalyzing = true);

    try {
      final geminiService = sl<GeminiCloudAiService>();
      final topLabels = _mergedCandidates.map((c) => c.label).toList();
      final cloudResult = await geminiService.analyzeCropImage(
        imagePath: widget.imagePath,
        initialTopCandidates: topLabels,
      );

      if (!mounted) return;

      setState(() {
        _isCloudAnalyzing = false;
        if (_mergedCandidates.isNotEmpty) {
          final boostedConfidence = cloudResult.confidence.clamp(0.0, 0.98);
          _allConfidences[0] = boostedConfidence;
          _mergedCandidates[0] = (label: cloudResult.label, confidence: boostedConfidence);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Gemini Cloud AI completed visual audit: ${cloudResult.label} (${(cloudResult.confidence * 100).toStringAsFixed(0)}%)'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCloudAnalyzing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gemini Cloud AI fallback: $e'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ── Agronomist Extension Officer Escalation Fallback ─────────────────────

  Future<void> _escalateToAgronomist() async {
    if (_isEscalating) return;
    setState(() => _isEscalating = true);

    try {
      final communityRepo = sl<ICommunityRepository>();
      final authService = sl<FirebaseAuthService>();
      final user = authService.currentUser;

      final topLabel = _mergedCandidates.isNotEmpty
          ? _mergedCandidates.first.label
          : 'Uncertain Scan';

      final post = CommunityPost(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user?.uid ?? 'anonymous',
        author: user?.displayName ?? 'Local Farmer',
        tag: 'Expert Escalation',
        body: 'Low-confidence AI scan ($topLabel). Requesting expert verification from extension officers or community agronomists.',
        imageUri: widget.imagePath,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await communityRepo.addPost(post);

      if (!mounted) return;
      setState(() => _isEscalating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escalation request submitted to Extension Officers & Community Experts!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isEscalating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit escalation request: $e'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Interactive Symptom Diagnostic Refiner ───────────────────────────────

  void _showSymptomRefinerModal() {
    final availableSymptoms = [
      'Dark sunken lesions / pod rot',
      'White powdery fungal growth',
      'Yellowing / Chlorotic leaves',
      'Swollen shoot / stem swellings',
      'Water-soaked circular spots',
      'Deformed leaves or fruit distortion',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colors = context.colors;
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Refine Diagnosis with Symptoms',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select all observed visual symptoms on your crop to help narrow down the AI prediction:',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onBackgroundSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSymptoms.map((symptom) {
                      final isSelected = _selectedSymptoms.contains(symptom);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(symptom),
                        selectedColor: colors.primary.withValues(alpha: 0.2),
                        checkmarkColor: colors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? colors.primary
                              : colors.onBackground,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedSymptoms.add(symptom);
                            } else {
                              _selectedSymptoms.remove(symptom);
                            }
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        _selectedSymptoms.isEmpty
                            ? 'Done'
                            : 'Apply Symptom Filter (${_selectedSymptoms.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Candidate Confirmation ────────────────────────────────────────────────

  void _confirmCandidate(TopCandidate candidate) {
    final displayName = candidate.label.replaceAll('_', ' ');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Diagnosis: $displayName'),
        content: Text(
          'Do you want to accept "$displayName" as your final diagnosis and save it to your crop scan history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final detection = await context.read<ScannerProvider>().saveMergedScan(
                    imagePath: widget.imagePath,
                    diseaseLabel: candidate.label,
                    confidence: candidate.confidence,
                    topCandidates: _mergedCandidates,
                    isDegraded: false,
                  );
              if (mounted && detection != null) {
                context.replace('/result/${detection.id}');
              } else if (mounted) {
                context.go('/home');
              }
            },
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );
  }

  bool _submittedCandidate = false;

  void _submitLowConfidenceCandidate() {
    if (_submittedCandidate) return;
    _submittedCandidate = true;

    final uid = sl<FirebaseAuthService>().currentUserId;
    if (uid.isEmpty) return;

    final candidateData = {
      'userId': uid,
      'imagePath': widget.imagePath,
      'topCandidates': _mergedCandidates
          .map((c) => {'label': c.label, 'confidence': c.confidence})
          .toList(),
      'averageConfidence': _averageConfidence,
      'anglesUsed': _anglesCaptured,
      'modelVersion': CropDiseaseClassifier.modelVersion,
      'deviceInfo': Platform.operatingSystem,
      'status': 'pending_review',
    };

    unawaited(sl<ICommunityRepository>().submitTrainingCandidate(candidateData));
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
        _submitLowConfidenceCandidate();
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
              _submitLowConfidenceCandidate();
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
                        onSelectCandidate: _confirmCandidate,
                      ),

                    const SizedBox(height: 16),

                    // ── Fallback Helpers Row (Cloud AI & Symptom Refiner) ───
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: colors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: _isCloudAnalyzing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Icon(Icons.auto_awesome,
                                    size: 18, color: colors.primary),
                            label: Text(
                              _isCloudAnalyzing
                                  ? 'Analyzing...'
                                  : 'Gemini Cloud AI',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                            onPressed: _isCloudAnalyzing
                                ? null
                                : _requestCloudAiAnalysis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: colors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(Icons.tune_rounded,
                                size: 18, color: colors.primary),
                            label: Text(
                              _selectedSymptoms.isEmpty
                                  ? 'Refine Symptoms'
                                  : 'Symptoms (${_selectedSymptoms.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                            onPressed: _showSymptomRefinerModal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Agronomist Escalation Fallback Button ────────────────
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: colors.info),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isEscalating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.contact_support_outlined,
                                size: 18, color: colors.info),
                        label: Text(
                          _isEscalating
                              ? 'Submitting Request...'
                              : 'Escalate to Agronomist Expert',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.info,
                          ),
                        ),
                        onPressed: _isEscalating ? null : _escalateToAgronomist,
                      ),
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

/// Card that shows the model's top-3 guesses with mini confidence bars & selection action.
class _TopCandidatesCard extends StatelessWidget {
  final List<TopCandidate> candidates;
  final CropColors colors;
  final ValueChanged<TopCandidate>? onSelectCandidate;

  const _TopCandidatesCard({
    required this.candidates,
    required this.colors,
    this.onSelectCandidate,
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
              const Spacer(),
              Text(
                'Tap candidate to confirm',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onBackgroundSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...candidates.asMap().entries.map((entry) {
            final isTop = entry.key == 0;
            final c = entry.value;
            final pct = (c.confidence * 100).toInt();
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onSelectCandidate != null
                  ? () => onSelectCandidate!(c)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 16, color: colors.onBackgroundSecondary),
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
