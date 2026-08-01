import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/locale_formatter.dart';
import '../../../core/utils/tts_manager.dart';
import '../../../domain/models/treatment_plan.dart';
import '../../components/cropguard_card.dart';
import 'treatment_tracker_provider.dart';

enum _PlanFilter { all, active, completed }

class TreatmentTrackerScreen extends StatefulWidget {
  const TreatmentTrackerScreen({super.key});

  @override
  State<TreatmentTrackerScreen> createState() => _TreatmentTrackerScreenState();
}

class _TreatmentTrackerScreenState extends State<TreatmentTrackerScreen> {
  final ScrollController _scrollController = ScrollController();
  _PlanFilter _selectedFilter = _PlanFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<TreatmentTrackerProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Consumer<TreatmentTrackerProvider>(
      builder: (context, provider, child) {
        final activeGroups = provider.activeGroups;
        final completedGroups = provider.completedGroups;
        final totalGroupsCount = activeGroups.length + completedGroups.length;

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

        return PopScope(
          canPop: Navigator.of(context).canPop(),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            context.go('/home');
          },
          child: Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.surface,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.treatmentTracker,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    activeGroups.isEmpty && completedGroups.isNotEmpty
                        ? context.l10n.allCaughtUp
                        : '${activeGroups.length} active ${activeGroups.length == 1 ? 'plan' : 'plans'} • ${completedGroups.length} completed',
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ],
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
              actions: [
                if (provider.plans.isNotEmpty)
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
                    : totalGroupsCount == 0
                        ? _EmptyState()
                        : Column(
                            children: [
                              const SizedBox(height: 12),
                              _FilterBar(
                                filter: _selectedFilter,
                                activeCount: activeGroups.length,
                                completedCount: completedGroups.length,
                                totalCount: totalGroupsCount,
                                onFilterChanged: (f) {
                                  setState(() => _selectedFilter = f);
                                },
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: provider.refresh,
                                  child: ListView(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 96),
                                    children: [
                                      if (_selectedFilter == _PlanFilter.all) ...[
                                        if (activeGroups.isNotEmpty) ...[
                                          _SectionHeader(
                                            title: 'Active Treatment Plans',
                                            count: activeGroups.length,
                                            icon: Icons.pending_actions_rounded,
                                            color: colors.primary,
                                          ),
                                          const SizedBox(height: 8),
                                          for (final group in activeGroups)
                                            _TreatmentPlanCard(
                                              group: group,
                                              key: ValueKey(group.groupId),
                                            ),
                                          const SizedBox(height: 16),
                                        ],
                                        if (completedGroups.isNotEmpty) ...[
                                          _SectionHeader(
                                            title: 'Completed Treatment Plans',
                                            count: completedGroups.length,
                                            icon: Icons.check_circle_rounded,
                                            color: colors.healthy,
                                          ),
                                          const SizedBox(height: 8),
                                          for (final group in completedGroups)
                                            _TreatmentPlanCard(
                                              group: group,
                                              key: ValueKey(group.groupId),
                                            ),
                                        ],
                                      ] else if (_selectedFilter ==
                                          _PlanFilter.active) ...[
                                        if (activeGroups.isEmpty)
                                          const _FilteredEmptyState(
                                            title: 'No Active Plans',
                                            subtitle:
                                                'All your treatment plans have been completed!',
                                            icon: Icons.task_alt_rounded,
                                          )
                                        else
                                          for (final group in activeGroups)
                                            _TreatmentPlanCard(
                                              group: group,
                                              key: ValueKey(group.groupId),
                                            ),
                                      ] else ...[
                                        if (completedGroups.isEmpty)
                                          const _FilteredEmptyState(
                                            title: 'No Completed Plans Yet',
                                            subtitle:
                                                'Complete all steps in a treatment plan to compile it here.',
                                            icon: Icons.assignment_turned_in_outlined,
                                          )
                                        else
                                          for (final group in completedGroups)
                                            _TreatmentPlanCard(
                                              group: group,
                                              key: ValueKey(group.groupId),
                                            ),
                                      ],
                                      if (provider.isLoadingMore)
                                        const Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 16),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
          ),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _PlanFilter filter;
  final int activeCount;
  final int completedCount;
  final int totalCount;
  final ValueChanged<_PlanFilter> onFilterChanged;

  const _FilterBar({
    required this.filter,
    required this.activeCount,
    required this.completedCount,
    required this.totalCount,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterChip(
            label: 'All ($totalCount)',
            isSelected: filter == _PlanFilter.all,
            onTap: () => onFilterChanged(_PlanFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Active ($activeCount)',
            isSelected: filter == _PlanFilter.active,
            onTap: () => onFilterChanged(_PlanFilter.active),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Completed ($completedCount)',
            isSelected: filter == _PlanFilter.completed,
            color: colors.healthy,
            onTap: () => onFilterChanged(_PlanFilter.completed),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeColor = color ?? colors.primary;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : colors.onBackground,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: colors.surface,
      side: BorderSide(
        color: isSelected ? activeColor : colors.border,
      ),
      onSelected: (_) => onTap(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.onBackground,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TreatmentPlanCard extends StatefulWidget {
  final TreatmentPlanGroup group;

  const _TreatmentPlanCard({required this.group, super.key});

  @override
  State<_TreatmentPlanCard> createState() => _TreatmentPlanCardState();
}

class _TreatmentPlanCardState extends State<_TreatmentPlanCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final group = widget.group;
    final isDone = group.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CropGuardCard(
        backgroundColor: isDone
            ? colors.healthyBg.withValues(alpha: 0.35)
            : colors.surface,
        borderColor: isDone
            ? colors.healthy.withValues(alpha: 0.4)
            : colors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Header Card
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDone
                          ? colors.healthy.withValues(alpha: 0.15)
                          : colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.eco_rounded,
                      color: isDone ? colors.healthy : colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group.cropType} — ${group.diseaseName}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colors.onBackground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              isDone
                                  ? 'Compiled • All ${group.totalStepsCount} steps done'
                                  : '${group.completedStepsCount} of ${group.totalStepsCount} steps done',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDone ? colors.healthy : colors.muted,
                                fontWeight: isDone
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.diseaseRed.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    tooltip: 'Delete Plan',
                    onPressed: () => _confirmDeleteGroup(context, group),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colors.muted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: group.progress,
                minHeight: 5,
                backgroundColor: colors.border.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDone ? colors.healthy : colors.primary,
                ),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // Steps Checklist
              Column(
                children: [
                  for (final step in group.steps)
                    _StepItemTile(
                      step: step,
                      key: ValueKey(step.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, TreatmentPlanGroup group) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Treatment Plan?'),
        content: Text(
          'This will permanently delete the treatment plan for "${group.cropType} — ${group.diseaseName}" and all its steps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TreatmentTrackerProvider>().deletePlanGroup(group);
            },
            child: Text(
              context.l10n.delete,
              style: TextStyle(color: colors.diseaseRed),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItemTile extends StatelessWidget {
  final TreatmentPlan step;

  const _StepItemTile({required this.step, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final provider = context.read<TreatmentTrackerProvider>();

    return Dismissible(
      key: ValueKey(step.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: colors.diseaseRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete_outline, color: colors.diseaseRed, size: 20),
      ),
      onDismissed: (_) => provider.deletePlan(step.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              checked: step.completed,
              label: step.step,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => provider.toggleStepById(step.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.completed ? colors.healthy : Colors.transparent,
                    border: Border.all(
                      color: step.completed ? colors.healthy : colors.border,
                      width: 2,
                    ),
                  ),
                  child: step.completed
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.step,
                    style: TextStyle(
                      color: step.completed ? colors.muted : colors.onBackground,
                      decoration:
                          step.completed ? TextDecoration.lineThrough : null,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 11, color: colors.muted),
                      const SizedBox(width: 4),
                      Text(
                        'Due ${LocaleFormatter.formatMonthDayYear(context, step.dueDate)}',
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
            IconButton(
              icon: Icon(Icons.volume_up_rounded, size: 18, color: colors.primary),
              tooltip: 'Listen to Step',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () {
                final langCode = Localizations.localeOf(context).languageCode;
                TtsManager().speak(step.step, languageCode: langCode);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _FilteredEmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: colors.healthy.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: colors.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
          Icon(Icons.check_circle_outline, size: 72, color: colors.healthy),
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
