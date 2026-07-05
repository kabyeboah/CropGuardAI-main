import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/repositories/i_auth_repository.dart';
import '../../components/cropguard_text_field.dart';
import '../../components/primary_button.dart';

/// In-app completion of a password reset. Reached when the user taps the reset
/// link in their email and the app intercepts the deep link (see
/// DeepLinkService). The [oobCode] is the Firebase one-time action code carried
/// in the link — never the user's password.
class ResetPasswordScreen extends StatefulWidget {
  final String oobCode;

  const ResetPasswordScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final IAuthRepository _auth = sl<IAuthRepository>();

  bool _verifying = true;
  bool _codeValid = false;
  bool _submitting = false;
  bool _done = false;
  String _password = '';
  String _confirm = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    final res = await _auth.verifyPasswordResetCode(widget.oobCode);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _codeValid = res.isSuccess;
    });
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_password.length < 6) {
      setState(() => _error = l10n.passwordMin6);
      return;
    }
    if (_password != _confirm) {
      setState(() => _error = l10n.passwordsDoNotMatch);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await _auth.confirmPasswordReset(
        code: widget.oobCode, newPassword: _password);
    if (!mounted) return;
    if (res.isSuccess) {
      setState(() {
        _submitting = false;
        _done = true;
      });
    } else {
      setState(() {
        _submitting = false;
        _error = l10n.resetLinkInvalid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resetPasswordTitle),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      backgroundColor: colors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _verifying
            ? const Center(child: CircularProgressIndicator())
            : !_codeValid
                ? _Message(
                    icon: Icons.link_off,
                    color: colors.error,
                    text: l10n.resetLinkInvalid,
                    cta: l10n.backToLogin,
                    onCta: () => context.go('/login'),
                  )
                : _done
                    ? _Message(
                        icon: Icons.check_circle,
                        color: colors.healthy,
                        text: l10n.passwordResetSuccess,
                        cta: l10n.backToLogin,
                        onCta: () => context.go('/login'),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l10n.enterNewPasswordHint,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 20),
                          CropGuardTextField(
                            value: _password,
                            onChanged: (v) => setState(() => _password = v),
                            label: l10n.newPassword,
                            placeholder: '••••••••',
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          CropGuardTextField(
                            value: _confirm,
                            onChanged: (v) => setState(() => _confirm = v),
                            label: l10n.confirmPassword,
                            placeholder: '••••••••',
                            obscureText: true,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: TextStyle(color: colors.error)),
                          ],
                          const SizedBox(height: 24),
                          PrimaryButton(
                            text: l10n.resetPasswordCta,
                            isLoading: _submitting,
                            onPressed: _submitting ? null : _submit,
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String cta;
  final VoidCallback onCta;

  const _Message({
    required this.icon,
    required this.color,
    required this.text,
    required this.cta,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          PrimaryButton(text: cta, onPressed: onCta),
        ],
      ),
    );
  }
}
