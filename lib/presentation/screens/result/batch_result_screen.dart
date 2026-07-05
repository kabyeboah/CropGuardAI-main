import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../components/primary_button.dart';
import '../../components/severity_badge.dart';
import 'batch_result_provider.dart';

class BatchResultScreen extends StatelessWidget {
  const BatchResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BatchResultProvider>();
    final colors = context.colors;
    final result = provider.batchResult;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.batchScanSummary,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: colors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : result == null
              ? Center(child: Text(context.l10n.noResultsLoaded))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Aggregated summary card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: colors.border)),
                        color: colors.surfaceVariant,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.info_outline,
                                  color: colors.primary, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.aggregatedResult,
                                style: TextStyle(
                                    color: colors.onBackgroundSecondary,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                result.aggregatedSummary,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        height: 1.3),
                              ),
                              const SizedBox(height: 16),
                              SeverityBadge(severity: result.overallSeverity),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n.individualLeafResults,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Individual results list
                      ...result.results.map((detection) => Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: colors.border)),
                            color: colors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          detection.displayName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          '${(detection.confidence * 100).toInt()}% confidence',
                                          style: TextStyle(
                                              color:
                                                  colors.onBackgroundSecondary,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SeverityBadge(severity: detection.severity),
                                ],
                              ),
                            ),
                          )),

                      const SizedBox(height: 32),

                      PrimaryButton(
                        text: context.l10n.scanAnotherBatch,
                        onPressed: () => context.go('/scanner'),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}
