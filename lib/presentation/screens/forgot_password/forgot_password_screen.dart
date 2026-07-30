import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../components/cropguard_text_field.dart';
import '../../components/primary_button.dart';
import 'forgot_password_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Selector<ForgotPasswordProvider, ForgotPasswordStatus>(
      selector: (_, p) => p.status,
      builder: (context, status, _) {
        final isSuccess = status == ForgotPasswordStatus.success;
        return PopScope(
          canPop: Navigator.of(context).canPop(),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            context.go('/login');
          },
          child: Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.background,
              elevation: 0,
              leading: BackButton(
                color: colors.onBackground,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/login');
                  }
                },
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: isSuccess
                    ? _SuccessView(
                        email: context.read<ForgotPasswordProvider>().sentEmail,
                        cooldown: context
                            .select<ForgotPasswordProvider, int>(
                                (p) => p.resendCooldown),
                        onResend: () => context
                            .read<ForgotPasswordProvider>()
                            .send(_emailController.text),
                        onBackToLogin: () => context.go('/login'),
                      )
                    : _FormView(emailController: _emailController),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FormView extends StatelessWidget {
  final TextEditingController emailController;
  const _FormView({required this.emailController});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.lock_reset_outlined,
              size: 28, color: colors.primary),
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.forgotPassword,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your email and we'll send you a link to reset your password.",
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colors.muted),
        ),
        const SizedBox(height: 32),
        CropGuardTextField(
          controller: emailController,
          label: context.l10n.email,
          placeholder: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        // Error + send button — only this sub-tree rebuilds from provider
        Selector<ForgotPasswordProvider, (ForgotPasswordStatus, String?)>(
          selector: (_, p) => (p.status, p.errorMessage),
          builder: (context, state, _) {
            final (status, error) = state;
            final isLoading = status == ForgotPasswordStatus.loading;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.diseaseBg,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: colors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      error,
                      style: TextStyle(color: colors.error, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  text: context.l10n.sendResetLink,
                  isLoading: isLoading,
                  onPressed: isLoading
                      ? null
                      : () => context
                          .read<ForgotPasswordProvider>()
                          .send(emailController.text),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: Text(
              context.l10n.backToLogin,
              style: TextStyle(color: colors.muted, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String email;
  final int cooldown;
  final VoidCallback onResend;
  final VoidCallback onBackToLogin;

  const _SuccessView({
    required this.email,
    required this.cooldown,
    required this.onResend,
    required this.onBackToLogin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.healthyBg,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mark_email_read_outlined,
              size: 28, color: colors.healthy),
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.checkInbox,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.muted),
            children: [
              TextSpan(text: context.l10n.resetLinkSentTo),
              TextSpan(
                text: email,
                style: TextStyle(
                    color: colors.onBackground,
                    fontWeight: FontWeight.w600),
              ),
              const TextSpan(
                  text: ". Check your spam folder if you don't see it."),
            ],
          ),
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          text: context.l10n.backToLogin,
          onPressed: onBackToLogin,
        ),
        const SizedBox(height: 16),
        Center(
          child: cooldown > 0
              ? Text(
                  context.l10n.resendIn(cooldown),
                  style: TextStyle(color: colors.muted, fontSize: 14),
                )
              : TextButton(
                  onPressed: onResend,
                  child: Text(
                    context.l10n.resendLink,
                    style: TextStyle(color: colors.primary, fontSize: 14),
                  ),
                ),
        ),
      ],
    );
  }
}
