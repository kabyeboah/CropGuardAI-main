import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/device_layout.dart';
import '../../components/cropguard_text_field.dart';
import '../../components/primary_button.dart';
import '../../components/screen_content.dart';
import 'login_provider.dart';

/// Equivalent of LoginScreen.kt
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginBody();
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final FocusNode _emailFocusNode = FocusNode();

  @override
  void dispose() {
    _emailFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoginProvider>();
    final colors = context.colors;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: ScreenContent(
            children: [
              // Logo / heading
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child:
                          const Icon(Icons.eco, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(context.l10n.welcomeBack,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(context.l10n.loginSubtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: colors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Email
              CropGuardTextField(
                focusNode: _emailFocusNode,
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

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      context.push('/forgot_password', extra: provider.email),
                  child: Text(context.l10n.forgotPassword,
                      style: TextStyle(color: colors.primary, fontSize: 13)),
                ),
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

              // Sign in button
              PrimaryButton(
                text: 'Sign In',
                isLoading: provider.status == LoginStatus.loading,
                onPressed: () => provider.signIn(
                  () => context.go('/home'),
                  onMigrationNeeded: (count) =>
                      _showMigrationDialog(context, provider, count),
                ),
              ),
              const SizedBox(height: 16),

              // Divider
              Row(children: [
                Expanded(child: Divider(color: colors.divider)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(context.l10n.orDivider,
                      style: TextStyle(color: colors.muted, fontSize: 12)),
                ),
                Expanded(child: Divider(color: colors.divider)),
              ]),
              const SizedBox(height: 16),

              // Google sign-in
              _SocialButton(
                label: context.l10n.signInWithGoogle,
                icon: Icons.login,
                onTap: () => provider.signInWithGoogle(
                  () => context.go('/home'),
                  onMigrationNeeded: (count) =>
                      _showMigrationDialog(context, provider, count),
                ),
              ),
              const SizedBox(height: 10),

              // Guest
              _SocialButton(
                label: context.l10n.guestLogin,
                icon: Icons.person_outline,
                onTap: () =>
                    provider.signInAsGuest(() => context.go('/home')),
              ),
              const SizedBox(height: 32),

              // Register link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(context.l10n.dontHaveAccount,
                        style:
                            TextStyle(color: colors.muted, fontSize: 14)),
                    Semantics(
                      button: true,
                      child: GestureDetector(
                      onTap: () => context.go('/register'),
                      child: Text(context.l10n.register,
                          style: TextStyle(
                              color: colors.greenXL,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
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
  LoginProvider provider,
  int count,
) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Text(context.l10n.keepGuestScansTitle),
      content: Text(
        'You have $count scan${count == 1 ? '' : 's'} from your guest session. '
        'Would you like to keep them in your account?',
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

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SocialButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        height: DeviceLayout.socialButtonHeight,
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(DeviceLayout.buttonCornerRadius),
          color: colors.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colors.onBackground, size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.onBackground)),
          ],
        ),
      ),
    );
  }
}
