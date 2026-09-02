import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../config/app_secrets.dart';
import 'app_logger.dart';

/// Receives inbound deep links (Android App Links / iOS Universal Links) and
/// routes them in-app. Currently handles Firebase password-reset links so the
/// email link opens the app's in-app reset screen instead of a web page.
///
/// For this to deliver links to the app (rather than a browser), the link's
/// domain must be verified for the app — see docs/PASSWORD_RESET_DEEPLINK.md.
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Starts listening. Handles the cold-start link (app opened by the link) and
  /// any links received while the app is already running.
  Future<void> init(GoRouter router) async {
    // Guard against double-init leaking the previous subscription.
    await _sub?.cancel();
    _sub = null;
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) handleUri(initial, router);
    } catch (e, s) {
      AppLogger.e('Failed to read initial deep link', e, s);
    }
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => handleUri(uri, router),
      onError: (Object e, StackTrace s) =>
          AppLogger.e('Deep link stream error', e, s),
    );
  }

  final Map<String, void Function(Uri uri, GoRouter router)> _customHandlers =
      {};

  /// Register custom deep link handler for a given path prefix (e.g., '/outbreak').
  void registerHandler(
      String pathPrefix, void Function(Uri uri, GoRouter router) handler) {
    _customHandlers[pathPrefix] = handler;
  }

  @visibleForTesting
  void handleUri(Uri uri, GoRouter router) {
    // 1. Validate scheme
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      AppLogger.w('Rejected deep link with invalid scheme: ${uri.scheme}');
      return;
    }

    // 2. Check custom handlers first
    for (final entry in _customHandlers.entries) {
      if (uri.path.startsWith(entry.key)) {
        entry.value(uri, router);
        return;
      }
    }

    // 3. Validate host (must match password reset continue URL host)
    try {
      final expectedUri = Uri.parse(AppSecrets.passwordResetContinueUrl);
      if (uri.host != expectedUri.host) {
        AppLogger.w('Rejected deep link with unauthorized host: ${uri.host}');
        return;
      }
    } catch (e, s) {
      AppLogger.e('Failed to parse configured continue URL host', e, s);
      return;
    }

    final params = uri.queryParameters;
    final code = params['code'] ?? params['token_hash'] ?? params['oobCode'];
    final mode = params['mode'];
    final isRecoveryFragment = uri.fragment.contains('type=recovery');
    final isReset =
        mode == 'resetPassword' ||
        uri.path.contains('reset-password') ||
        isRecoveryFragment;

    if (isReset && ((code != null && code.isNotEmpty) || isRecoveryFragment)) {
      final safeCode = code ?? '';
      // 4. Validate code against safe characters (Supabase/Firebase tokens)
      if (safeCode.isNotEmpty) {
        final codeRegex = RegExp(r'^[a-zA-Z0-9\-_=.]+$');
        if (!codeRegex.hasMatch(safeCode)) {
          AppLogger.e('Rejected deep link with malformed or suspicious code.');
          return;
        }
      }

      // 5. Validate mode parameter if present
      if (mode != null && mode.isNotEmpty) {
        final modeRegex = RegExp(r'^[a-zA-Z0-9]+$');
        if (!modeRegex.hasMatch(mode)) {
          AppLogger.e('Rejected deep link with malformed mode.');
          return;
        }
      }

      final encodedCode = Uri.encodeComponent(safeCode);
      router.go('/reset_password?oobCode=$encodedCode');
    } else {
      AppLogger.w('Received deep link that is not a password reset action.');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
