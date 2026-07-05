import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../components/cropguard_card.dart';

class PlantingCalendarWidget extends StatelessWidget {
  final String status;
  final String action;

  const PlantingCalendarWidget({
    super.key,
    required this.status,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CropGuardCard(
      backgroundColor: colors.primary.withValues(alpha: 0.05),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_month, color: colors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.seasonalCalendar(status),
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action,
                  style: TextStyle(
                    color: colors.onBackgroundSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
