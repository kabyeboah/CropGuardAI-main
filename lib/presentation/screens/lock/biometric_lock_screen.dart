import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_lock_controller.dart';
import '../../../core/utils/biometric_service.dart';
import '../../../data/remote/supabase_auth_service.dart';
import '../../components/primary_button.dart';

/// Shown when the biometric app-lock is active. Auto-prompts on open; offers a
/// retry and a "log out" escape so a user who can't authenticate is never
/// trapped.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final AppLockController _lock = sl<AppLockController>();
  final BiometricService _biometric = sl<BiometricService>();
  bool _inProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    if (_inProgress) return;
    setState(() => _inProgress = true);
    _lock.markAuthenticating(true);
    final ok = await _biometric.authenticate(context.l10n.unlockReason);
    _lock.markAuthenticating(false);
    if (!mounted) return;
    if (ok) {
      _lock.unlock();
      context.go('/home');
    } else {
      setState(() => _inProgress = false);
    }
  }

  Future<void> _logout() async {
    // Clear the lock first so the post-logout login flow isn't re-gated.
    _lock.unlock();
    await sl<SupabaseAuthService>().signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 72, color: colors.primary),
              const SizedBox(height: 24),
              Text(
                l10n.appLockedTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.appLockedSubtitle,
                style: TextStyle(color: colors.onBackgroundSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                text: l10n.unlock,
                icon: Icons.fingerprint,
                isLoading: _inProgress,
                onPressed: _inProgress ? null : _attempt,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _logout,
                child: Text(l10n.signOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
