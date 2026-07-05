import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/device_layout.dart';
import '../../components/cropguard_text_field.dart';
import '../../components/primary_button.dart';
import '../../components/screen_content.dart';
import 'register_provider.dart';

/// Equivalent of RegisterScreen.kt — name/email/password, strength bar, terms
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RegisterBody();
  }
}

class _RegisterBody extends StatelessWidget {
  const _RegisterBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RegisterProvider>();
    final colors = context.colors;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: ScreenContent(
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Text(context.l10n.createAccount,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(context.l10n.registerSubtitle,
                        style: TextStyle(color: colors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Name
              CropGuardTextField(
                value: provider.name,
                onChanged: provider.setName,
                label: context.l10n.fullName,
                placeholder: context.l10n.exampleName,
              ),
              const SizedBox(height: DeviceLayout.sectionSpacing),

              // Email
              CropGuardTextField(
                value: provider.email,
                onChanged: provider.setEmail,
                label: context.l10n.email,
                placeholder: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: DeviceLayout.sectionSpacing),

              // Password
              CropGuardTextField(
                value: provider.password,
                onChanged: provider.setPassword,
                label: context.l10n.password,
                placeholder: '••••••••',
                obscureText: provider.obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(provider.obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: provider.togglePasswordVisibility,
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: DeviceLayout.sectionSpacing),
              CropGuardTextField(
                value: provider.confirmPassword,
                onChanged: provider.setConfirmPassword,
                label: context.l10n.confirmPassword,
                placeholder: '••••••••',
                obscureText: provider.obscurePassword,
              ),
              const SizedBox(height: 8),

              // Strength bar
              _PasswordStrengthBar(strength: provider.passwordStrength),
              const SizedBox(height: 16),

              // Terms checkbox
              Row(
                children: [
                  Checkbox(
                    value: provider.termsAccepted,
                    onChanged: (v) => provider.setTermsAccepted(v ?? false),
                    activeColor: colors.primaryLight,
                    side: BorderSide(color: colors.border),
                  ),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${context.l10n.agreeToThe} ',
                            style: TextStyle(
                                color: colors.muted, fontSize: 12)),
                        GestureDetector(
                          onTap: () => context.push('/terms_of_service'),
                          child: Text(context.l10n.termsOfService,
                              style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        Text(' ${context.l10n.and} ',
                            style: TextStyle(
                                color: colors.muted, fontSize: 12)),
                        GestureDetector(
                          onTap: () => context.push('/privacy_policy'),
                          child: Text(context.l10n.privacyPolicy,
                              style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Error
              if (provider.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.diseaseBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(provider.errorMessage!,
                      style: TextStyle(color: colors.error, fontSize: 13)),
                ),

              // Register button
              PrimaryButton(
                text: context.l10n.createAccount,
                isLoading: provider.status == RegisterStatus.loading,
                onPressed: () => provider.register(
                  () => context.go('/home'),
                  onMigrationNeeded: (count) =>
                      _showMigrationDialog(context, provider, count),
                ),
              ),
              const SizedBox(height: 24),

              // Sign in link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${context.l10n.hasAccountPrompt} ',
                        style:
                            TextStyle(color: colors.muted, fontSize: 14)),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(context.l10n.signIn,
                          style: TextStyle(
                              color: colors.greenXL,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showMigrationDialog(
  BuildContext context,
  RegisterProvider provider,
  int count,
) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Text(context.l10n.keepGuestScansTitle),
      content: Text(
        'You have $count scan${count == 1 ? '' : 's'} from your guest session. '
        'Would you like to keep them in your new account?',
      ),
      actions: [
        TextButton(
          onPressed: provider.declineMigration,
          child: Text(context.l10n.discard),
        ),
        ElevatedButton(
          onPressed: provider.acceptMigration,
          child: Text(context.l10n.keepScans),
        ),
      ],
    ),
  );
}

/// Password strength bar — matches PasswordStrengthBar composable in RegisterScreen.kt
class _PasswordStrengthBar extends StatelessWidget {
  final int strength; // 0–4

  const _PasswordStrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labels = ['', 'Weak', 'Fair', 'Strong', 'Very Strong'];
    final segColors = [colors.error, colors.warning, colors.healthy, colors.primary];

    if (strength == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final filled = i < strength;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 3,
                decoration: BoxDecoration(
                  color: filled
                      ? segColors[i < segColors.length ? i : segColors.length - 1]
                      : colors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          'Strength: ${labels[strength.clamp(0, labels.length - 1)]}',
          style: TextStyle(color: colors.muted, fontSize: 11),
        ),
      ],
    );
  }
}
