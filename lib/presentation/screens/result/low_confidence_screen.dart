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
import '../../../data/remote/supabase_auth_service.dart';
import '../../../data/remote/gemini_cloud_ai_service.dart';
import '../../../domain/models/cloud_ai_analysis_result.dart';
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
  CloudAiAnalysisResult? _cloudResult;
  String? _cloudError;

  @override
  void initState() {
    super.initState();
    _allConfidences = [widget.confidence];
    final initialCandidates = List<TopCandidate>.from(widget.topCandidates);

    List<DiseaseRisk> risks = widget.regionalRisks ?? const [];
    if (risks.isEmpty) {
      try {
        final homeProvider = context.read<HomeProvider>();
        if (homeProvider.weeklyRisks.isNotEmpty) {
          risks = homeProvider.weeklyRisks;
        } else if (homeProvider.weather != null &&
            homeProvider.weather!.daily.isNotEmpty) {
          final region =
              homeProvider.weather!.latitude > 8.0 ? 'North' : 'South';
          risks = AgriWeatherUtils.assessWeeklyRisks(
            homeProvider.weather!.daily,
            outbreaks: homeProvider.outbreaks,
            region: region,
          );
        }
      } catch (_) {}
    }

    // Regional Outbreak Risk-Weighted adjustment
    final regionalRiskAdjusted =
        RiskWeightedClassifier.adjustCandidatesWithRegionalRisk(
      candidates: initialCandidates,
      regionalRisks: risks,
    );

    _allPhotosCandidates = [regionalRiskAdjusted];
    _recomputeSoftVotingCandidates();

    // Auto-trigger Gemini Cloud AI fallback if below threshold (0.60)
    if (widget.confidence < CropDiseaseClassifier.confidenceThreshold) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestCloudAiAnalysis();
        }
      });
    }
  }

  void _recomputeSoftVotingCandidates() {
    _mergedCandidates = CropDiseaseClassifier.computeSoftVotingCandidates(
      _allPhotosCandidates,
    );
    if (_mergedCandidates.isEmpty && widget.topCandidates.isNotEmpty) {
      _mergedCandidates = List<TopCandidate>.from(widget.topCandidates);
    }
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
    setState(() {
      _isCloudAnalyzing = true;
      _cloudError = null;
    });

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
        _cloudResult = cloudResult;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCloudAnalyzing = false;
        _cloudError = e.toString();
      });
    }
  }

  Future<void> _acceptCloudResult(CloudAiAnalysisResult result) async {
    final scannerProvider = context.read<ScannerProvider>();
    final detection = await scannerProvider.saveMergedScan(
      imagePath: widget.imagePath,
      diseaseLabel: result.label,
      confidence: result.confidence,
      topCandidates: _mergedCandidates,
      isDegraded: false,
    );
    if (!mounted) return;
    if (detection != null) {
      context.replace('/result/${detection.id}');
    }
  }

  // ── Agronomist Extension Officer Escalation Fallback ─────────────────────

  Future<void> _escalateToAgronomist() async {
    if (_isEscalating) return;
    setState(() => _isEscalating = true);

    try {
      final communityRepo = sl<ICommunityRepository>();
      final authService = sl<SupabaseAuthService>();
      final user = authService.currentUser;

      final topLabel = _mergedCandidates.isNotEmpty
          ? _mergedCandidates.first.label
          : 'Uncertain Scan';

      final post = CommunityPost(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user?.id ?? 'anonymous',
        author: authService.currentUserName,
        tag: 'Expert Escalation',
        body:
            'Low-confidence AI scan ($topLabel). Requesting expert verification from extension officers or community agronomists.',
        imageUri: widget.imagePath,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await communityRepo.addPost(post);

      if (!mounted) return;
      setState(() => _isEscalating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Escalation request submitted to Extension Officers & Community Experts!'),
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
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
                          color:
                              isSelected ? colors.primary : colors.onBackground,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final detection =
                  await context.read<ScannerProvider>().saveMergedScan(
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

    final uid = sl<SupabaseAuthService>().currentUserId;
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

    unawaited(
        sl<ICommunityRepository>().submitTrainingCandidate(candidateData));
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final avgConfidence = _averageConfidence;
    final topCandidateConfidence = _mergedCandidates.isNotEmpty
        ? _mergedCandidates.first.confidence
        : avgConfidence;
    final pct = (topCandidateConfidence * 100).toInt();
    final rawPct = (avgConfidence * 100).toInt();

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

                    // ── 1. PRIMARY RECOMMENDED SECTION: Gemini Cloud AI ──
                    if (_isCloudAnalyzing)
                      CropGuardCard(
                        backgroundColor: colors.surface,
                        borderColor: colors.primary.withValues(alpha: 0.4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      colors.primary),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Consulting Gemini Cloud AI...',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: colors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Auditing low-confidence scan with multimodal pathology model',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onBackgroundSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_cloudResult != null)
                      _CloudAiResultCard(
                        result: _cloudResult!,
                        colors: colors,
                        onAccept: () => _acceptCloudResult(_cloudResult!),
                      )
                    else if (_cloudError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: colors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off,
                                size: 20, color: colors.warning),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Cloud AI unavailable (offline or unconfigured). Showing on-device preliminary results below.',
                                style: TextStyle(
                                    fontSize: 12, color: colors.onBackground),
                              ),
                            ),
                            TextButton(
                              onPressed: _requestCloudAiAnalysis,
                              child: Text(context.l10n.retry),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── 2. SUBORDINATE SECTION: On-Device Model (Collapsed ExpansionTile) ──
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: CropGuardCard(
                        backgroundColor: colors.surface,
                        padding: EdgeInsets.zero,
                        child: Material(
                          color: Colors.transparent,
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            leading: Icon(Icons.memory_outlined,
                                size: 22, color: colors.lowConfidence),
                            title: Text(
                              'On-Device Preliminary Guess ($pct% - Low Confidence)',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.onBackground,
                                  ),
                            ),
                            subtitle: Text(
                              rawPct != pct
                                  ? 'Regional risk-adjusted: $pct% (Raw model: $rawPct%)'
                                  : 'Local model estimate below 0.60 threshold (unverified)',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onBackgroundSecondary,
                              ),
                            ),
                            children: [
                              Text(
                                context.l10n.lowConfidenceExplanation(pct),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              ConfidenceBar(
                                confidence: topCandidateConfidence,
                                color: colors.lowConfidence,
                              ),
                              if (_anglesCaptured > 1) ...[
                                const SizedBox(height: 8),
                                _AnglePill(
                                  captured: _anglesCaptured,
                                  total: _kMaxAngles,
                                  color: colors.lowConfidence,
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (_mergedCandidates.isNotEmpty)
                                _TopCandidatesCard(
                                  candidates: _mergedCandidates,
                                  colors: colors,
                                  onSelectCandidate: _confirmCandidate,
                                ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 38),
                                  side: BorderSide(color: colors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(Icons.tune_rounded,
                                    size: 16, color: colors.primary),
                                label: Text(
                                  _selectedSymptoms.isEmpty
                                      ? 'Refine Symptoms'
                                      : 'Symptoms Filter (${_selectedSymptoms.length})',
                                  style: TextStyle(
                                      fontSize: 12, color: colors.primary),
                                ),
                                onPressed: _showSymptomRefinerModal,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 3. Human Agronomist Escalation Button ────────────────
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: colors.info),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isEscalating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.contact_support_outlined,
                                size: 18, color: colors.info),
                        label: Text(
                          _isEscalating
                              ? 'Submitting Request...'
                              : 'Escalate to Agronomist Expert Review',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.info,
                          ),
                        ),
                        onPressed: _isEscalating ? null : _escalateToAgronomist,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 4. Persistent Scope Disclaimer (Task 3) ──────────────
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

                    const SizedBox(height: 20),

                    // ── 5. Multi-angle retry button ────────────────────────────
                    if (_canAddAngle)
                      PrimaryButton(
                        text: _isCapturing
                            ? context.l10n.analysing
                            : _anglesCaptured == 1
                                ? context.l10n.addAnotherAngle
                                : context.l10n
                                    .addAngle(_anglesCaptured + 1, _kMaxAngles),
                        icon: _isCapturing
                            ? Icons.hourglass_top
                            : Icons.add_a_photo,
                        onPressed:
                            _isCapturing ? null : _captureAdditionalAngle,
                      )
                    else
                      PrimaryButton(
                        text: context.l10n.tryAgain,
                        icon: Icons.camera_alt,
                        onPressed: () => context.go('/scanner'),
                      ),

                    const SizedBox(height: 12),

                    // ── 6. Community / fallback buttons ────────────────────────
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
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
              final uid = sl<SupabaseAuthService>().currentUserId;
              if (uid.isEmpty) {
                messenger.showSnackBar(SnackBar(content: Text(failMsg)));
                return;
              }
              final res = await sl<ICommunityRepository>().submitCropNotFound(
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
                  messenger.showSnackBar(SnackBar(content: Text(failMsg)));
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
                            fontWeight:
                                isTop ? FontWeight.bold : FontWeight.normal,
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

/// Card displaying the primary Gemini Cloud AI recommended diagnosis.
class _CloudAiResultCard extends StatelessWidget {
  final CloudAiAnalysisResult result;
  final CropColors colors;
  final VoidCallback onAccept;

  const _CloudAiResultCard({
    required this.result,
    required this.colors,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final confPct = (result.confidence * 100).toInt();

    return CropGuardCard(
      backgroundColor: colors.surface,
      borderColor: colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recommendation header badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Gemini Cloud AI Recommended',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$confPct% Confidence',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Primary headline disease label
          Text(
            result.label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onBackground,
                ),
          ),
          const SizedBox(height: 8),

          // Confidence Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: result.confidence,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),

          // Symptoms summary
          if (result.symptoms.isNotEmpty) ...[
            Text(
              'Observed Pathological Symptoms:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.onBackground,
              ),
            ),
            const SizedBox(height: 6),
            ...result.symptoms.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 6),
                        child:
                            Icon(Icons.circle, size: 6, color: colors.primary),
                      ),
                      Expanded(
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onBackgroundSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
          ],

          // Root cause
          if (result.rootCause.isNotEmpty) ...[
            Text(
              'Underlying Root Cause:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.onBackground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.rootCause,
              style: TextStyle(
                fontSize: 12,
                color: colors.onBackgroundSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Primary Action: Accept & Save
          PrimaryButton(
            text: 'Accept & Save Cloud Diagnosis',
            icon: Icons.check_circle_outline,
            onPressed: onAccept,
          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
              label: Text(
                context.l10n.viewMySubmissions,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: onViewSubmissions,
            ),
          ),
        ],
      ),
    );
  }
}
