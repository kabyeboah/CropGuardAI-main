import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/connectivity_service.dart';

/// Connection-status banner. Hidden when online; shows an offline warning, or a
/// softer "weak connection" notice when reachable but slow. Driven entirely by
/// automatic detection — there is no manual offline switch.
class OfflineBanner extends StatelessWidget {
  final ConnectionStatus status;

  const OfflineBanner({super.key, required this.status});

  /// Convenience for callers that only track a hard-offline bool.
  factory OfflineBanner.fromOffline(bool isOffline) => OfflineBanner(
        status: isOffline ? ConnectionStatus.offline : ConnectionStatus.online,
      );

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionStatus.online) return const SizedBox.shrink();

    final colors = context.colors;
    final isOffline = status == ConnectionStatus.offline;
    final message = isOffline
        ? context.l10n.offlineBanner
        : context.l10n.weakConnectionBanner;

    return Container(
      width: double.infinity,
      color:
          isOffline ? colors.warning : colors.warning.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(isOffline ? Icons.wifi_off : Icons.network_check,
              size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
