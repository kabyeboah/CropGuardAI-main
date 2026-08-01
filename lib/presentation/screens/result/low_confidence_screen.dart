import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../components/confidence_bar.dart';
import '../../components/cropguard_card.dart';
import '../../components/primary_button.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/repositories/i_community_repository.dart';
import '../../../data/remote/firebase_auth_service.dart';

class LowConfidenceScreen extends StatefulWidget {
  final double confidence;
  final String imagePath;

  const LowConfidenceScreen({
    super.key,
    required this.confidence,
    required this.imagePath,
  });

  @override
  State<LowConfidenceScreen> createState() => _LowConfidenceScreenState();
}

class _LowConfidenceScreenState extends State<LowConfidenceScreen> {
  bool _reportSent = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pct = (widget.confidence * 100).toInt();

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
          // Blurred image preview
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
                          confidence: widget.confidence,
                          color: colors.lowConfidence,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    context.l10n.lowConfidenceTips,
                    style: TextStyle(
                        color: colors.onBackgroundSecondary, fontSize: 14,
                        height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  PrimaryButton(
                    text: context.l10n.tryAgain,
                    icon: Icons.camera_alt,
                    onPressed: () => context.go('/scanner'),
                  ),
                  const SizedBox(height: 12),

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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(context.l10n.reportSubmittedThanks,
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              final crop = cropController.text;
              final symptoms = symptomsController.text;
              Navigator.pop(ctx);

              final messenger = ScaffoldMessenger.of(context);
              final failMsg = context.l10n.submitReportFailed;
              final uid = sl<FirebaseAuthService>().currentUserId;
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
      // Dispose the dialog-scoped controllers once it closes.
      cropController.dispose();
      symptomsController.dispose();
    });
  }
}
