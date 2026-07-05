import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/remote/firebase_auth_service.dart';
import '../../components/cropguard_text_field.dart';
import '../../components/section_label.dart';
import 'settings_provider.dart';

/// Equivalent of SettingsScreen.kt
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final colors = context.colors;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settings,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(l10n.settingsSubtitle,
                style: TextStyle(
                    color: colors.onBackgroundSecondary, fontSize: 12)),
          ],
        ),
      ),
      body: ListView(
        children: [
          _ActionRow(
            label: l10n.myProfile,
            onTap: () => context.push('/profile'),
          ),
          // Display section
          _SectionHeader(l10n.sectionDisplay),
          _ThemeModeRow(
            value: provider.themeMode,
            onChanged: provider.setThemeMode,
            labelLight: l10n.themeLight,
            labelAuto: l10n.themeAuto,
            labelDark: l10n.themeDark,
            themeLabel: l10n.theme,
          ),
          _ToggleRow(
            label: l10n.largeTextMode,
            value: provider.largeTextMode,
            onChanged: provider.setLargeTextMode,
          ),
          _ToggleRow(
            label: l10n.showConfidenceScore,
            value: provider.showConfidence,
            onChanged: provider.setShowConfidence,
          ),
          _ToggleRow(
            label: l10n.shareAnalytics,
            value: provider.analyticsEnabled,
            onChanged: provider.setAnalyticsEnabled,
          ),
          if (provider.biometricAvailable)
            _ToggleRow(
              label: l10n.biometricLock,
              value: provider.biometricLockEnabled,
              onChanged: provider.setBiometricLockEnabled,
            ),
          _LanguageRow(
            label: l10n.language,
            value: provider.locale?.languageCode,
            onChanged: provider.setLocale,
          ),

          // Model & data section
          _SectionHeader(l10n.sectionModelData),
          _InfoRow(
            label: l10n.modelVersion,
            value: provider.updateMessageCode?.resolve(context.l10n) ?? 'MobileNetV2 v1.0 (bundled)',
            badge: l10n.modelVersionActive,
            actionLabel: provider.isCheckingUpdates
                ? l10n.checkingUpdates
                : l10n.checkUpdates,
            onAction: provider.isCheckingUpdates
                ? null
                : provider.checkForModelUpdates,
          ),
          _InfoRow(
            label: context.l10n.supportedCrops,
            value: '93 disease classes across 27 crops — '
                'Cassava, Cocoa, Yam, Plantain, Oil Palm, Cashew, Cowpea, '
                'Sorghum, Millet, Groundnut, Pepper Chilli, Maize, Tomato, '
                'Rice, Banana, Potato, Soybean, Pepper Bell, Squash, Apple, '
                'Blueberry, Cherry, Grape, Orange, Peach, Raspberry, Strawberry',
          ),
          _ActionRow(
            label: l10n.clearScanHistory,
            color: colors.diseaseRed,
            onTap: () => _confirmClear(context, provider),
          ),
          _ActionRow(
            label: l10n.deleteAccount,
            color: colors.diseaseRed,
            onTap: () => _confirmDelete(context, provider),
          ),

          // About section
          _SectionHeader(l10n.sectionAbout),
          _InfoRow(
            label: l10n.appVersion,
            value: provider.appVersionLabel,
          ),
          _InfoRow(
            label: context.l10n.disclaimerLabel,
            value: l10n.disclaimer,
          ),
          _ActionRow(
            label: l10n.privacyPolicy,
            onTap: () => context.push('/privacy_policy'),
          ),
          _ActionRow(
            label: l10n.termsOfService,
            onTap: () => context.push('/terms_of_service'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, SettingsProvider provider) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearHistoryTitle),
        content: Text(l10n.clearHistoryBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(ctx);
            },
            child: Text(l10n.clearScanHistory,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SettingsProvider provider) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountTitle,
            style: const TextStyle(color: Colors.red)),
        content: Text(l10n.deleteAccountBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finalDeleteConfirmation(context, provider);
            },
            child: Text(l10n.yesIAmSure,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _finalDeleteConfirmation(BuildContext context, SettingsProvider provider) {
    final auth = sl<FirebaseAuthService>();
    _showReauthAndDeleteDialog(context, provider, auth);
  }

  void _showReauthAndDeleteDialog(
    BuildContext context,
    SettingsProvider provider,
    FirebaseAuthService auth,
  ) {
    final l10n = context.l10n;
    String password = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.confirmDeletion,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.reauthDescription),
              if (auth.hasPasswordProvider) ...[
                const SizedBox(height: 16),
                CropGuardTextField(
                  value: password,
                  onChanged: (v) => setState(() => password = v),
                  label: l10n.password,
                  obscureText: true,
                ),
              ],
              if (provider.deleteErrorCode != null) ...[
                const SizedBox(height: 8),
                Text(provider.deleteErrorCode!.resolve(context.l10n),
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: provider.isDeleting ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            if (auth.hasGoogleProvider && !auth.hasPasswordProvider)
              TextButton(
                onPressed: provider.isDeleting
                    ? null
                    : () async {
                        await provider.deleteAccount(
                          onSuccess: () {
                            Navigator.pop(ctx);
                            context.go('/login');
                          },
                          reauthWithGoogle: true,
                        );
                      },
                child: Text(l10n.confirmWithGoogle),
              ),
            TextButton(
              onPressed: provider.isDeleting
                  ? null
                  : () async {
                      await provider.deleteAccount(
                        onSuccess: () {
                          Navigator.pop(ctx);
                          context.go('/login');
                        },
                        password:
                            auth.hasPasswordProvider ? password : null,
                        reauthWithGoogle:
                            auth.hasGoogleProvider && password.isEmpty,
                      );
                    },
              child: provider.isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.deletePermanently,
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: SectionLabel(text: title),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow(
      {required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodyLarge),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
        Divider(height: 0, color: colors.divider,
            indent: 16, endIndent: 16),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionRow(
      {required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: color ?? colors.onBackground,
                        )),
                Icon(Icons.chevron_right, color: colors.muted),
              ],
            ),
          ),
        ),
        Divider(height: 0, color: colors.divider,
            indent: 16, endIndent: 16),
      ],
    );
  }
}

class _ThemeModeRow extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  final String themeLabel;
  final String labelLight;
  final String labelAuto;
  final String labelDark;

  const _ThemeModeRow({
    required this.value,
    required this.onChanged,
    required this.themeLabel,
    required this.labelLight,
    required this.labelAuto,
    required this.labelDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(themeLabel, style: Theme.of(context).textTheme.bodyLarge),
              SegmentedButton<ThemeMode>(
                // Selected segment uses the app's green accent rather than the
                // default Material secondaryContainer, for token consistency.
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: colors.primary,
                  selectedForegroundColor: Colors.white,
                ),
                segments: [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode, size: 16),
                    label: Text(labelLight),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto, size: 16),
                    label: Text(labelAuto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode, size: 16),
                    label: Text(labelDark),
                  ),
                ],
                selected: {value},
                onSelectionChanged: (modes) => onChanged(modes.first),
              ),
            ],
          ),
        ),
        Divider(height: 0, color: colors.divider, indent: 16, endIndent: 16),
      ],
    );
  }
}

/// Language picker. `null` value = follow system. Non-English locales fall back
/// to English for any string not yet translated (see l10n/app_*.arb).
class _LanguageRow extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _LanguageRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              DropdownButton<String?>(
                value: value,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(context.l10n.systemLanguage),
                  ),
                  ...SettingsProvider.supportedLanguages.entries.map(
                    (e) => DropdownMenuItem<String?>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  ),
                ],
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        Divider(height: 0, color: colors.divider, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? badge;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InfoRow(
      {required this.label,
      required this.value,
      this.badge,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: Theme.of(context).textTheme.bodyLarge),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.healthyBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(badge!,
                          style: TextStyle(
                              color: colors.healthy,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const Spacer(),
                  if (actionLabel != null)
                    TextButton(
                      onPressed: onAction,
                      child: Text(actionLabel!,
                          style: TextStyle(
                              color: colors.primary, fontSize: 13)),
                    ),
                ],
              ),
              Text(value,
                  style: TextStyle(
                      color: colors.onBackgroundSecondary,
                      fontSize: 13)),
            ],
          ),
        ),
        Divider(height: 0, color: colors.divider,
            indent: 16, endIndent: 16),
      ],
    );
  }
}
