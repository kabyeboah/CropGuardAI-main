import 'package:flutter/material.dart';
import '../../core/utils/scan_severity.dart';
import '../../core/theme/app_theme.dart';

/// Coloured severity badge — matches SeverityBadge.kt
class SeverityBadge extends StatelessWidget {
  final String severity;

  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Color bg;
    Color fg;
    switch (severity.toLowerCase()) {
      case ScanSeverity.healthy:
        bg = colors.primary;
        fg = Colors.white;
        break;
      case ScanSeverity.early:
        bg = colors.severityEarly;
        fg = Colors.white;
        break;
      case ScanSeverity.moderate:
        bg = colors.severityModerate;
        fg = Colors.white;
        break;
      case ScanSeverity.severe:
        bg = colors.severitySevere;
        fg = Colors.white;
        break;
      case ScanSeverity.warning:
        bg = colors.warning;
        fg = Colors.black;
        break;
      case ScanSeverity.unclear:
        bg = colors.lowConfidence;
        fg = Colors.white;
        break;
      default:
        bg = colors.surfaceVariant;
        fg = colors.onBackground;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        severity.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Status badge (Healthy / Diseased / At Risk) — matches StatusBadge.kt
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Color bg;
    Color fg;
    String label;
    switch (status.toLowerCase()) {
      case 'diseased':
        bg = colors.badgeDiseasedBg;
        fg = colors.error;
        label = 'Diseased';
        break;
      case 'healthy':
        bg = colors.badgeHealthyBg;
        fg = colors.healthy;
        label = 'Healthy';
        break;
      case 'at risk':
      case 'warning':
        bg = colors.badgeWarningBg;
        fg = colors.warning;
        label = 'At Risk';
        break;
      default:
        bg = colors.surfaceVariant;
        fg = colors.muted;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg),
      ),
    );
  }
}
