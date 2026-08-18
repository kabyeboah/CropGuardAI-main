import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/scan_feedback_helper.dart';
import '../../../core/utils/tts_manager.dart';
import '../scanner/scanner_provider.dart';
import '../../../data/ml/crop_disease_classifier.dart';
import '../../../domain/models/low_confidence_extra.dart';

/// Intermediate screen that runs TFLite inference on the captured image
/// Equivalent of the "analyzing" state in ScannerViewModel / ScannerScreen
class AnalisingScreen extends StatefulWidget {
  final String imagePath;

  const AnalisingScreen({super.key, required this.imagePath});

  @override
  State<AnalisingScreen> createState() => _AnalisingScreenState();
}

class _AnalisingScreenState extends State<AnalisingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _analyse();
  }

  Future<void> _analyse() async {
    final provider = context.read<ScannerProvider>();
    final result = await provider.analyseAndSave(widget.imagePath);

    if (!mounted) return;

    if (result == null) {
      final errorMsg = provider.errorMessage ?? context.l10n.analysisFailed;
      final isEngineUnavailable = errorMsg.contains('ML engine unavailable');

      if (isEngineUnavailable) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(child: Text(context.l10n.scanEngineUnavailable)),
              ],
            ),
            content: const Text(
              "The scan engine couldn't start on this device. "
              "You can ask the farming community for disease identification.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home');
                },
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.replace('/community');
                },
                child: Text(context.l10n.askCommunity),
              ),
            ],
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMsg,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
    }

    final lang = Localizations.localeOf(context).languageCode;
    final summary = result.isHealthy
        ? context.l10n.scanSummaryHealthy(result.displayName)
        : context.l10n.scanSummaryDiseased(result.displayName);

    await ScanFeedbackHelper.playScanComplete(
      isHealthy: result.isHealthy,
      soundEnabled: true,
      hapticEnabled: true,
    );

    if (!mounted) return;

    await TtsManager().speak(summary, languageCode: lang);

    if (!mounted) return;

    // Two-tier confidence gate:
    //   < 0.60  → low-confidence screen (candidates, Gemini Cloud AI, report form).
    //   ≥ 0.60  → full result screen.
    const double kLowConfidenceThreshold = CropDiseaseClassifier.confidenceThreshold;

    if (result.confidence < kLowConfidenceThreshold) {
      context.replace(
        '/low_confidence',
        extra: LowConfidenceExtra(
          confidence: result.confidence,
          imagePath: result.imagePath,
          topCandidates: result.topCandidates,
        ),
      );
    } else {
      context.replace('/result/${result.id}');
    }
  }

  @override
  void dispose() {
    // Stop any in-flight spoken summary so audio doesn't outlive the screen.
    TtsManager().stop();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Image preview
              if (File(widget.imagePath).existsSync())
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                  ),
                ),

              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RotationTransition(
                          turns: _spin,
                          child: Icon(Icons.eco, size: 72, color: colors.primary),
                        ),
                        const SizedBox(height: 24),
                        Text(context.l10n.analysing,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.analysingDesc,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colors.onBackgroundSecondary,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 32),
                        LinearProgressIndicator(
                          backgroundColor: colors.border,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(colors.primary),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
