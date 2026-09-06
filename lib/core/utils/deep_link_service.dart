import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../config/app_secrets.dart';
import 'app_logger.dart';

/// Receives inbound deep links (Android App Links / iOS Universal Links) and
/// routes them in-app. Currently handles password-reset links so the
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
  void handleUri(Uri uri, GoRouter router) async {
    // 1. Check custom handlers first
    for (final entry in _customHandlers.entries) {
      if (uri.path.startsWith(entry.key)) {
        entry.value(uri, router);
        return;
      }
    }

    // 2. Validate scheme
    final scheme = uri.scheme.toLowerCase();
    const allowedSchemes = {'http', 'https', 'io.supabase.cropguard', 'cropguard'};
    if (!allowedSchemes.contains(scheme)) {
      AppLogger.w('Rejected deep link with invalid scheme: ${uri.scheme}');
      return;
    }

    // 3. Check for Password Reset flow
    final isRecoveryFragment = uri.fragment.contains('type=recovery');
    final params = uri.queryParameters;
    final code = params['code'] ?? params['token_hash'] ?? params['oobCode'];
    final mode = params['mode'];
    final isReset = mode == 'resetPassword' ||
        uri.host == 'reset-password' ||
        uri.path.contains('reset-password') ||
        isRecoveryFragment ||
        params['type'] == 'recovery';

    if (isReset) {
      // Validate host for HTTP/HTTPS links
      if (scheme == 'http' || scheme == 'https') {
        try {
          final expectedUri = Uri.parse(AppSecrets.passwordResetContinueUrl);
          if (uri.host != expectedUri.host &&
              uri.host != 'cropguardai.app' &&
              uri.host != 'localhost') {
            AppLogger.w('Rejected deep link with unauthorized host: ${uri.host}');
            return;
          }
        } catch (e, s) {
          AppLogger.e('Failed to parse configured continue URL host', e, s);
          return;
        }
      }

      final safeCode = code ?? '';
      // Validate code against safe characters (Supabase tokens)
      if (safeCode.isNotEmpty) {
        final codeRegex = RegExp(r'^[a-zA-Z0-9\-_=.]+$');
        if (!codeRegex.hasMatch(safeCode)) {
          AppLogger.e('Rejected deep link with malformed or suspicious code.');
          return;
        }
      }

      // Validate mode parameter if present
      if (mode != null && mode.isNotEmpty) {
        final modeRegex = RegExp(r'^[a-zA-Z0-9]+$');
        if (!modeRegex.hasMatch(mode)) {
          AppLogger.e('Rejected deep link with malformed mode.');
          return;
        }
      }

      // If session tokens are present in hash/query, restore Supabase session
      if (uri.fragment.isNotEmpty || uri.queryParameters.containsKey('access_token')) {
        try {
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
        } catch (e) {
          AppLogger.w('Supabase getSessionFromUrl error during recovery: $e');
        }
      }

      final encodedCode = Uri.encodeComponent(safeCode);
      router.go('/reset_password?oobCode=$encodedCode');
      return;
    }

    // 4. Handle Supabase OAuth callback URI
    if (uri.host == 'login-callback' || uri.path.contains('login-callback')) {
      AppLogger.i('Handling Supabase OAuth callback deep link: $uri');
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        if (Supabase.instance.client.auth.currentSession != null) {
          router.go('/home');
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (Supabase.instance.client.auth.currentSession != null) {
            router.go('/home');
          }
        }
      } catch (e, s) {
        AppLogger.e('Failed to extract Supabase session from URL', e, s);
      }
      return;
    }

    AppLogger.w('Received deep link that is not recognized: $uri');
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
