import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

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
      if (initial != null) _handle(initial, router);
    } catch (e, s) {
      AppLogger.e('Failed to read initial deep link', e, s);
    }
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, router),
      onError: (Object e, StackTrace s) =>
          AppLogger.e('Deep link stream error', e, s),
    );
  }

  void _handle(Uri uri, GoRouter router) {
    final params = uri.queryParameters;
    final code = params['oobCode'];
    final mode = params['mode'];
    final isReset =
        mode == 'resetPassword' || uri.path.contains('reset-password');
    if (code != null && code.isNotEmpty && isReset) {
      router.go('/reset_password?oobCode=$code');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
