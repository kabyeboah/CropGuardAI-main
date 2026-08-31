import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../components/cropguard_card.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(context.l10n.more,
            style: Theme.of(context).textTheme.titleLarge),
        elevation: 0,
      ),
      body: ListView(
        // Bottom inset so the last tile clears the docked scan FAB that
        // overlays the body above the BottomAppBar.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _MoreTile(
            icon: Icons.person_outline,
            title: context.l10n.profile,
            subtitle: context.l10n.profileSubtitle,
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: context.l10n.settings,
            subtitle: context.l10n.settingsSubtitleShort,
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.assignment_turned_in_outlined,
            title: context.l10n.mySubmissions,
            subtitle: context.l10n.mySubmissionsSubtitle,
            onTap: () => context.push('/submissions'),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.calculate_outlined,
            title: 'Spray & Chemical Calculator',
            subtitle: 'Knapsack tank capacity & chemical mixing ratios',
            onTap: () => context.push('/dosage_calculator'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _MoreTile(
            icon: Icons.info_outline,
            title: context.l10n.aboutCropGuard,
            subtitle: context.l10n.aboutSubtitleVersion,
            onTap: () async {
              final info = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              // Custom dialog instead of showAboutDialog so the framework's
              // "View licenses" page is not shipped to end users.
              unawaited(showDialog<void>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  icon: Icon(Icons.eco, color: colors.primary, size: 48),
                  title: const Text('CropGuard AI'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'v${info.version} (${info.buildNumber})',
                        style: Theme.of(dialogCtx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Text(dialogCtx.l10n.aboutCropGuardDesc),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: Text(dialogCtx.l10n.close),
                    ),
                  ],
                ),
              ));
            },
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CropGuardCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle,
                    style: TextStyle(color: colors.muted, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.muted),
        ],
      ),
    );
  }
}
