import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../components/cropguard_card.dart';
import 'treatment_tracker_provider.dart';

class TreatmentTrackerScreen extends StatelessWidget {
  const TreatmentTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Consumer<TreatmentTrackerProvider>(
      builder: (context, provider, child) {
        final plans = provider.plans;
        final pending = plans.where((t) => !t.completed).length;
        final completed = plans.where((t) => t.completed).length;

        // One-time confirmation when a plan was auto-created from the library.
        if (provider.seededPlan) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (provider.consumeSeededFlag()) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.treatmentPlanAdded)),
              );
            }
          });
        }

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.treatmentTracker,
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                  pending == 0
                      ? context.l10n.allCaughtUp
                      : context.l10n.treatmentSubtitle(pending, completed),
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
            leading: BackButton(onPressed: () => context.pop()),
            actions: [
              if (plans.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: colors.muted),
                  onPressed: provider.refresh,
                  tooltip: context.l10n.refresh,
                ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: colors.diseaseRed),
                          const SizedBox(height: 12),
                          Text(
                            'Error: ${provider.error}',
                            style: TextStyle(color: colors.diseaseRed),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: provider.refresh,
                            icon: const Icon(Icons.refresh),
                            label: Text(context.l10n.retry),
                          ),
                        ],
                      ),
                    )
                  : plans.isEmpty
                      ? _EmptyState()
                      : RefreshIndicator(
                          onRefresh: provider.refresh,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                            itemCount: plans.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final t = plans[i];
                              return Dismissible(
                                key: ValueKey(t.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: colors.diseaseRed.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.delete_outline,
                                      color: colors.diseaseRed),
                                ),
                                onDismissed: (_) => provider.deletePlan(t.id),
                                child: CropGuardCard(
                                  backgroundColor: t.completed
                                      ? colors.healthyBg.withValues(alpha: 0.4)
                                      : colors.surface,
                                  borderColor: t.completed
                                      ? colors.healthy.withValues(alpha: 0.3)
                                      : colors.border,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Semantics(
                                        checked: t.completed,
                                        label: t.step,
                                        excludeSemantics: true,
                                        child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => provider.toggleComplete(i),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          width: 28,
                                          height: 28,
                                          margin: const EdgeInsets.only(
                                              top: 2, right: 12),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: t.completed
                                                ? colors.healthy
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: t.completed
                                                  ? colors.healthy
                                                  : colors.border,
                                              width: 2,
                                            ),
                                          ),
                                          child: t.completed
                                              ? const Icon(Icons.check,
                                                  size: 16,
                                                  color: Colors.white)
                                              : null,
                                        ),
                                      ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${t.cropType} — ${t.diseaseName}',
                                              style: TextStyle(
                                                color: colors
                                                    .onBackgroundSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              t.step,
                                              style: TextStyle(
                                                color: t.completed
                                                    ? colors.muted
                                                    : colors.onBackground,
                                                decoration: t.completed
                                                    ? TextDecoration
                                                        .lineThrough
                                                    : null,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today,
                                                    size: 11,
                                                    color: colors.muted),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Due ${t.dueDateFormatted}',
                                                  style: TextStyle(
                                                    color: colors.muted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 72, color: colors.healthy),
          const SizedBox(height: 12),
          Text(context.l10n.noTreatmentPlansYet,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            context.l10n.treatmentEmptyHelp,
            style: TextStyle(color: colors.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
