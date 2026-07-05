import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/scan_report_pdf_exporter.dart';
import '../../../domain/models/detection_result.dart';
import '../../components/severity_badge.dart';
import 'history_provider.dart';

/// Equivalent of HistoryScreen.kt
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistoryProvider>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: provider.exportMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.cancelSelection,
                onPressed: provider.exitExportMode,
              )
            : null,
        title: provider.exportMode
            ? Text(context.l10n.selectedCount(provider.exportSelectedIds.length),
                style: Theme.of(context).textTheme.titleLarge)
            : Text(context.l10n.scanHistoryTitle,
                style: Theme.of(context).textTheme.titleLarge),
        actions: provider.exportMode
            ? [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: context.l10n.exportSelected,
                  onPressed: provider.exportSelectedIds.isEmpty
                      ? null
                      : () async {
                          await ScanReportPdfExporter.shareMonthlyReport(
                              provider.exportSelectedScans);
                        },
                ),
              ]
            : [
                if (provider.filtered.isNotEmpty)
                  Semantics(
                    label: context.l10n.monthlySummaryReport,
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.summarize_outlined),
                      tooltip: context.l10n.monthlySummary,
                      onPressed: () async {
                        await ScanReportPdfExporter.shareMonthlyReport(
                            provider.filtered);
                      },
                    ),
                  ),
                PopupMenuButton<HistorySort>(
                  icon: const Icon(Icons.sort),
                  tooltip: context.l10n.sortTooltip,
                  onSelected: provider.setSort,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: HistorySort.dateNewest,
                      child: Text(context.l10n.sortNewest),
                    ),
                    PopupMenuItem(
                      value: HistorySort.dateOldest,
                      child: Text(context.l10n.sortOldest),
                    ),
                    PopupMenuItem(
                      value: HistorySort.confidenceDesc,
                      child: Text(context.l10n.sortMostConfident),
                    ),
                    PopupMenuItem(
                      value: HistorySort.confidenceAsc,
                      child: Text(context.l10n.sortLeastConfident),
                    ),
                    PopupMenuItem(
                      value: HistorySort.cropType,
                      child: Text(context.l10n.sortByCrop),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    provider.comparisonMode
                        ? Icons.close
                        : Icons.compare_arrows,
                    color: provider.comparisonMode
                        ? colors.primary
                        : colors.onBackground,
                  ),
                  onPressed: provider.toggleComparisonMode,
                  tooltip: context.l10n.comparisonModeLabel,
                ),
              ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: provider.setSearch,
              decoration: InputDecoration(
                hintText: context.l10n.searchHistoryHint,
                prefixIcon: Icon(Icons.search, color: colors.muted),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // Health filter chips + date range
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ...HistoryFilter.values.map((f) {
                  final labels = {
                    HistoryFilter.all: context.l10n.all,
                    HistoryFilter.healthy: context.l10n.healthy,
                    HistoryFilter.diseased: context.l10n.diseased,
                  };
                  final isSelected = provider.filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(labels[f]!),
                      selected: isSelected,
                      onSelected: (_) => provider.setFilter(f),
                      selectedColor: colors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : colors.onBackground,
                      ),
                      checkmarkColor: Colors.white,
                    ),
                  );
                }),
                // Date range picker chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      Icons.date_range,
                      size: 16,
                      color: (provider.dateFrom != null || provider.dateTo != null)
                          ? Colors.white
                          : colors.onBackground,
                    ),
                    label: Text(
                      provider.dateFrom != null || provider.dateTo != null
                          ? '${provider.dateFrom != null ? DateFormat('MMM d').format(provider.dateFrom!) : '…'} → ${provider.dateTo != null ? DateFormat('MMM d').format(provider.dateTo!) : '…'}'
                          : context.l10n.dateRange,
                    ),
                    backgroundColor:
                        (provider.dateFrom != null || provider.dateTo != null)
                            ? colors.primary
                            : null,
                    labelStyle: TextStyle(
                      color: (provider.dateFrom != null || provider.dateTo != null)
                          ? Colors.white
                          : colors.onBackground,
                    ),
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: provider.dateFrom != null && provider.dateTo != null
                            ? DateTimeRange(start: provider.dateFrom!, end: provider.dateTo!)
                            : null,
                      );
                      if (range != null) {
                        provider.setDateRange(range.start, range.end);
                      }
                    },
                  ),
                ),
                if (provider.hasActiveFilters)
                  ActionChip(
                    avatar: const Icon(Icons.clear, size: 16),
                    label: Text(context.l10n.clear),
                    onPressed: provider.clearFilters,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Crop type filter chips (derived from scan history)
          if (provider.availableCropTypes.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: provider.availableCropTypes.map((cropType) {
                  final isSelected = provider.cropTypeFilter.contains(cropType);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cropType, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (_) => provider.setCropTypeFilter(cropType),
                      selectedColor: colors.accent,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : colors.onBackground,
                        fontSize: 12,
                      ),
                      checkmarkColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            )
          else
            const SizedBox(height: 8),

          // Results list
          Expanded(
            child: provider.isLoading
                ? Center(
                    child:
                        CircularProgressIndicator(color: colors.primary))
                : provider.filtered.isEmpty
                    ? _EmptyHistory()
                    : RefreshIndicator(
                        onRefresh: provider.load,
                        child: ListView.separated(
                          // Bottom inset so the last row clears the docked scan
                          // FAB that overlays the body above the BottomAppBar.
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          itemCount: provider.filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final r = provider.filtered[i];
                            return _HistoryTile(
                              result: r,
                              comparisonMode: provider.comparisonMode,
                              selected: provider.selectedIds.contains(r.id),
                              exportMode: provider.exportMode,
                              exportSelected:
                                  provider.exportSelectedIds.contains(r.id),
                              onLongPress: provider.comparisonMode ||
                                      provider.exportMode
                                  ? null
                                  : () => provider.enterExportMode(r.id),
                              onTap: () {
                                if (provider.exportMode) {
                                  provider.toggleExportSelection(r.id);
                                } else if (provider.comparisonMode) {
                                  provider.toggleSelection(r.id);
                                } else {
                                  context.push('/result/${r.id}');
                                }
                              },
                              onDelete: () {
                                final deletedItem = r;
                                provider.deleteResult(r.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.l10n.scanDeleted),
                                    action: SnackBarAction(
                                      label: context.l10n.undo,
                                      onPressed: () =>
                                          provider.restoreDetection(deletedItem),
                                    ),
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: provider.exportMode &&
              provider.exportSelectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                await ScanReportPdfExporter.shareMonthlyReport(
                    provider.exportSelectedScans);
              },
              label:
                  Text(context.l10n.exportCount(provider.exportSelectedIds.length)),
              icon: const Icon(Icons.picture_as_pdf),
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
            )
          : provider.comparisonMode && provider.selectedIds.length == 2
              ? FloatingActionButton.extended(
                  onPressed: () => _showComparisonDialog(context, provider),
                  label: Text(context.l10n.compareScans),
                  icon: const Icon(Icons.compare),
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                )
              : null,
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final DetectionResult result;
  final bool comparisonMode;
  final bool selected;
  final bool exportMode;
  final bool exportSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;

  const _HistoryTile({
    required this.result,
    required this.comparisonMode,
    required this.selected,
    this.exportMode = false,
    this.exportSelected = false,
    required this.onTap,
    required this.onDelete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = DateFormat('MMM d, yyyy HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(result.timestamp),
    );

    return Dismissible(
      key: ValueKey(result.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? colors.healthyBg : colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: File(result.imagePath).existsSync()
                    ? Image.file(File(result.imagePath),
                        width: 56, height: 56, fit: BoxFit.cover)
                    : Container(
                        width: 56,
                        height: 56,
                        color: colors.surfaceVariant,
                        child:
                            Icon(Icons.image_not_supported, color: colors.muted),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(result.cropType,
                        style: TextStyle(
                            color: colors.muted, fontSize: 12)),
                    Text(date,
                        style: TextStyle(
                            color: colors.muted, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SeverityBadge(severity: result.severity),
                  const SizedBox(height: 4),
                  Text(
                      '${(result.confidence * 100).toInt()}%',
                      style: TextStyle(
                          color: colors.onBackgroundSecondary,
                          fontSize: 11)),
                ],
              ),
              if (exportMode)
                Checkbox(
                  value: exportSelected,
                  onChanged: (_) => onTap(),
                  activeColor: colors.primary,
                )
              else if (comparisonMode)
                Checkbox(
                  value: selected,
                  onChanged: (_) => onTap(),
                  activeColor: colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: colors.border),
          const SizedBox(height: 12),
          Text(context.l10n.noScansFound,
              style: TextStyle(
                  color: colors.onBackgroundSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(context.l10n.noScansFoundDesc,
              style: TextStyle(color: colors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

void _showComparisonDialog(BuildContext context, HistoryProvider provider) {
  final colors = context.colors;
  final scans = provider.selectedScans;
  if (scans.length < 2) return;

  final scan1 = scans[0];
  final scan2 = scans[1];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.compareScans,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First Scan Column
                  Expanded(
                    child: _ComparisonColumn(scan: scan1),
                  ),
                  const SizedBox(width: 16),
                  // Divider
                  Container(
                    width: 1,
                    height: 500,
                    color: colors.border,
                  ),
                  const SizedBox(width: 16),
                  // Second Scan Column
                  Expanded(
                    child: _ComparisonColumn(scan: scan2),
                  ),
                ],
              ),
            ),
          ),
          // Close button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  context.l10n.closeComparison,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ComparisonColumn extends StatelessWidget {
  final DetectionResult scan;

  const _ComparisonColumn({required this.scan});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = DateFormat('MMM d, yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(scan.timestamp),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: File(scan.imagePath).existsSync()
              ? Image.file(
                  File(scan.imagePath),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Container(
                  height: 140,
                  width: double.infinity,
                  color: colors.surfaceVariant,
                  child: const Icon(Icons.image_not_supported, size: 40),
                ),
        ),
        const SizedBox(height: 16),
        Text(
          scan.displayName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          scan.cropType,
          style: TextStyle(
            color: colors.muted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          context.l10n.severityLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        SeverityBadge(severity: scan.severity),
        const SizedBox(height: 16),
        Text(
          context.l10n.aiConfidence,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(scan.confidence * 100).toInt()}%',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.onBackground,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.scanDateLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date,
          style: TextStyle(
            fontSize: 14,
            color: colors.onBackgroundSecondary,
          ),
        ),
      ],
    );
  }
}
