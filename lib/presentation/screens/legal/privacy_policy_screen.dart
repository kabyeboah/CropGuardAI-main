import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/remote/supabase_auth_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final sections = [
      _Section(l10n.privacySection1Title, l10n.privacySection1Body),
      _Section(l10n.privacySection2Title, l10n.privacySection2Body),
      _Section(l10n.privacySection3Title, l10n.privacySection3Body),
      _Section(l10n.privacySection4Title, l10n.privacySection4Body),
      _Section(l10n.privacySection5Title, l10n.privacySection5Body),
    ];
    final isSignedIn = sl<SupabaseAuthService>().isSignedIn;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(isSignedIn ? '/home' : '/login');
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(l10n.privacyPolicy),
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(isSignedIn ? '/home' : '/login');
              }
            },
          ),
          backgroundColor: colors.surface,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.privacyPolicy,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l10n.privacyLastUpdated,
                  style: TextStyle(color: colors.muted, fontSize: 12)),
              const SizedBox(height: 20),
              ...sections.map((s) => _SectionView(section: s)),
            ],
          ),
        ),
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final sections = [
      _Section(l10n.termsSection1Title, l10n.termsSection1Body),
      _Section(l10n.termsSection2Title, l10n.termsSection2Body),
      _Section(l10n.termsSection3Title, l10n.termsSection3Body),
      _Section(l10n.termsSection4Title, l10n.termsSection4Body),
      _Section(l10n.termsSection5Title, l10n.termsSection5Body),
      _Section(l10n.termsSection6Title, l10n.termsSection6Body),
    ];
    final isSignedIn = sl<SupabaseAuthService>().isSignedIn;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(isSignedIn ? '/home' : '/login');
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(l10n.termsOfService),
          leading: BackButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(isSignedIn ? '/home' : '/login');
              }
            },
          ),
          backgroundColor: colors.surface,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.termsOfService,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l10n.termsEffective,
                  style: TextStyle(color: colors.muted, fontSize: 12)),
              const SizedBox(height: 20),
              ...sections.map((s) => _SectionView(section: s)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});
  final _Section section;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(section.body,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.6, color: colors.onBackgroundSecondary)),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Section {
  final String title;
  final String body;

  const _Section(this.title, this.body);
}
