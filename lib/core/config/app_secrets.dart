import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API keys and secrets — never commit real values, never bundle them as assets.
///
/// Resolution order (first non-empty value wins):
///   1. Compile-time  --dart-define=KEY=...
///   2. Runtime       KEY in a local .env (debug/dev only; not shipped)
///   3. Remote Config fetched at startup by AppBootstrap
///
/// `.env` is intentionally NOT a Flutter asset, so it is never packaged into a
/// release binary. Production builds supply secrets via --dart-define or Remote
/// Config. The dotenv lookups below are guarded with [_env] so they no-op when
/// dotenv was never loaded (the normal case in release).
class AppSecrets {
  AppSecrets._();

  // ── Testing Overrides (simulates --dart-define in unit tests) ───────────────
  @visibleForTesting
  static String? dartDefineGhanaNlpKeyOverride;
  @visibleForTesting
  static String? dartDefineCloudinaryCloudNameOverride;
  @visibleForTesting
  static String? dartDefineCloudinaryUploadPresetOverride;
  @visibleForTesting
  static String? dartDefinePasswordResetUrlOverride;
  @visibleForTesting
  static String? dartDefineAndroidPackageOverride;
  @visibleForTesting
  static String? dartDefineIosBundleIdOverride;
  @visibleForTesting
  static String? dartDefineGeminiApiKeyOverride;
  @visibleForTesting
  static String? dartDefineOsmTileUrlOverride;
  @visibleForTesting
  static String? dartDefineOsmUserAgentOverride;

  /// Resets all overrides and remote keys back to default/empty values.
  /// Intended for unit testing.
  @visibleForTesting
  static void reset() {
    dartDefineGhanaNlpKeyOverride = null;
    dartDefineCloudinaryCloudNameOverride = null;
    dartDefineCloudinaryUploadPresetOverride = null;
    dartDefinePasswordResetUrlOverride = null;
    dartDefineAndroidPackageOverride = null;
    dartDefineIosBundleIdOverride = null;
    dartDefineGeminiApiKeyOverride = null;
    dartDefineOsmTileUrlOverride = null;
    dartDefineOsmUserAgentOverride = null;

    _remoteGhanaNlpKey = null;
    _remoteCloudName = null;
    _remoteUploadPreset = null;
    _remotePasswordResetUrl = null;
    _remoteAndroidPackage = null;
    _remoteIosBundleId = null;
    _remoteGeminiApiKey = null;
    _remoteOsmTileUrl = null;
    _remoteOsmUserAgent = null;
  }

  /// Safe dotenv read: returns '' when dotenv isn't initialised (release) so
  /// accessing `dotenv.env` never throws NotInitializedError.
  static String _env(String key) {
    if (!dotenv.isInitialized) return '';
    return dotenv.env[key] ?? '';
  }

  // ── Ghana NLP (TTS / ASR) ───────────────────────────────────────────────────
  static String? _remoteGhanaNlpKey;

  static const _dartDefineKey = String.fromEnvironment(
    'GHANA_NLP_SUBSCRIPTION_KEY',
    defaultValue: '',
  );

  /// Subscription key for Ghana NLP. Null if not configured.
  static String? get ghanaNlpSubscriptionKey {
    final ddKey = dartDefineGhanaNlpKeyOverride ?? _dartDefineKey;
    if (ddKey.isNotEmpty) return ddKey;
    final envKey = _env('GHANA_NLP_SUBSCRIPTION_KEY');
    if (envKey.isNotEmpty) return envKey;
    return (_remoteGhanaNlpKey?.isNotEmpty == true) ? _remoteGhanaNlpKey : null;
  }

  /// Called by AppBootstrap when Remote Config returns a value.
  static void setGhanaNlpSubscriptionKey(String key) {
    if (key.isNotEmpty) _remoteGhanaNlpKey = key;
  }

  static bool get hasGhanaNlpKey =>
      ghanaNlpSubscriptionKey != null && ghanaNlpSubscriptionKey!.isNotEmpty;

  // ── Cloudinary ──────────────────────────────────────────────────────────────
  static String? _remoteCloudName;
  static String? _remoteUploadPreset;

  static const _dartDefineCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );
  static const _dartDefineUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );

  static String get cloudinaryCloudName {
    final ddName =
        dartDefineCloudinaryCloudNameOverride ?? _dartDefineCloudName;
    if (ddName.isNotEmpty) return ddName;
    final envVal = _env('CLOUDINARY_CLOUD_NAME');
    if (envVal.isNotEmpty) return envVal;
    return _remoteCloudName ?? '';
  }

  static String get cloudinaryUploadPreset {
    final ddPreset =
        dartDefineCloudinaryUploadPresetOverride ?? _dartDefineUploadPreset;
    if (ddPreset.isNotEmpty) return ddPreset;
    final envVal = _env('CLOUDINARY_UPLOAD_PRESET');
    if (envVal.isNotEmpty) return envVal;
    return _remoteUploadPreset ?? '';
  }

  /// Called by AppBootstrap when Remote Config returns Cloudinary values.
  static void setCloudinaryConfig({String? cloudName, String? uploadPreset}) {
    if (cloudName != null && cloudName.isNotEmpty) _remoteCloudName = cloudName;
    if (uploadPreset != null && uploadPreset.isNotEmpty) {
      _remoteUploadPreset = uploadPreset;
    }
  }

  static bool get hasCloudinaryConfig =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  // ── Password-reset deep-link URLs ───────────────────────────────────────────
  // The continue URL embedded in the password-reset email must be an Authorized
  // Domain in Firebase Console → Authentication → Settings, and must serve the
  // correct assetlinks.json / apple-app-site-association files so the OS opens
  // the app instead of a browser. Moving these values to Remote Config lets us
  // patch the domain without a Play Store / App Store release.

  static String? _remotePasswordResetUrl;
  static String? _remoteAndroidPackage;
  static String? _remoteIosBundleId;

  static const _dartDefinePasswordResetUrl = String.fromEnvironment(
    'PASSWORD_RESET_CONTINUE_URL',
    defaultValue: '',
  );
  static const _dartDefineAndroidPackage = String.fromEnvironment(
    'ANDROID_PACKAGE_NAME',
    defaultValue: '',
  );
  static const _dartDefineIosBundleId = String.fromEnvironment(
    'IOS_BUNDLE_ID',
    defaultValue: '',
  );

  // Fallback values — match the constants that were previously hardcoded in
  // FirebaseAuthService. These are safe to ship in the binary (they are not
  // secrets) but still benefit from Remote Config patching.
  static const _defaultPasswordResetUrl =
      'https://cropguardai.app/reset-password';
  static const _defaultAndroidPackage = 'com.crop.guard.app';
  static const _defaultIosBundleId = 'com.crop.guard.app';

  static String get passwordResetContinueUrl {
    final ddUrl =
        dartDefinePasswordResetUrlOverride ?? _dartDefinePasswordResetUrl;
    if (ddUrl.isNotEmpty) return ddUrl;
    final envVal = _env('PASSWORD_RESET_CONTINUE_URL');
    if (envVal.isNotEmpty) return envVal;
    return _remotePasswordResetUrl ?? _defaultPasswordResetUrl;
  }

  static String get androidPackageName {
    final ddPkg = dartDefineAndroidPackageOverride ?? _dartDefineAndroidPackage;
    if (ddPkg.isNotEmpty) return ddPkg;
    final envVal = _env('ANDROID_PACKAGE_NAME');
    if (envVal.isNotEmpty) return envVal;
    return _remoteAndroidPackage ?? _defaultAndroidPackage;
  }

  static String get iosBundleId {
    final ddIos = dartDefineIosBundleIdOverride ?? _dartDefineIosBundleId;
    if (ddIos.isNotEmpty) return ddIos;
    final envVal = _env('IOS_BUNDLE_ID');
    if (envVal.isNotEmpty) return envVal;
    return _remoteIosBundleId ?? _defaultIosBundleId;
  }

  /// Called by [AppBootstrap] when Remote Config returns deep-link config.
  static void setPasswordResetConfig({
    String? continueUrl,
    String? androidPackage,
    String? iosBundleId,
  }) {
    if (continueUrl != null && continueUrl.isNotEmpty) {
      _remotePasswordResetUrl = continueUrl;
    }
    if (androidPackage != null && androidPackage.isNotEmpty) {
      _remoteAndroidPackage = androidPackage;
    }
    if (iosBundleId != null && iosBundleId.isNotEmpty) {
      _remoteIosBundleId = iosBundleId;
    }
  }

  // ── Gemini Cloud AI ─────────────────────────────────────────────────────────
  static String? _remoteGeminiApiKey;

  static const _dartDefineGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Gemini API key for fallback cloud multimodal diagnosis.
  static String? get geminiApiKey {
    final ddKey = dartDefineGeminiApiKeyOverride ?? _dartDefineGeminiApiKey;
    if (ddKey.isNotEmpty) return ddKey;
    final envVal = _env('GEMINI_API_KEY');
    if (envVal.isNotEmpty) return envVal;
    return (_remoteGeminiApiKey?.isNotEmpty == true)
        ? _remoteGeminiApiKey
        : null;
  }

  /// Called by [AppBootstrap] when Remote Config returns a value.
  static void setGeminiApiKey(String key) {
    if (key.isNotEmpty) _remoteGeminiApiKey = key;
  }

  static bool get hasGeminiApiKey =>
      geminiApiKey != null && geminiApiKey!.isNotEmpty;

  // ── OpenStreetMap & Mapping Configuration ──────────────────────────────────
  static String? _remoteOsmTileUrl;
  static String? _remoteOsmUserAgent;

  static const _dartDefineOsmTileUrl = String.fromEnvironment(
    'OSM_TILE_URL',
    defaultValue: '',
  );
  static const _dartDefineOsmUserAgent = String.fromEnvironment(
    'OSM_USER_AGENT',
    defaultValue: '',
  );

  static const _defaultOsmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _defaultOsmUserAgent =
      'CropGuardAI/1.0 (com.crop.guard.app; support@cropguard.app)';

  /// Base raster tile server URL template for flutter_map.
  static String get osmTileUrl {
    final ddUrl = dartDefineOsmTileUrlOverride ?? _dartDefineOsmTileUrl;
    if (ddUrl.isNotEmpty) return ddUrl;
    final envVal = _env('OSM_TILE_URL');
    if (envVal.isNotEmpty) return envVal;
    return _remoteOsmTileUrl ?? _defaultOsmTileUrl;
  }

  /// Compliant User-Agent header for OpenStreetMap tile server and Nominatim API.
  static String get osmUserAgent {
    final ddUa = dartDefineOsmUserAgentOverride ?? _dartDefineOsmUserAgent;
    if (ddUa.isNotEmpty) return ddUa;
    final envVal = _env('OSM_USER_AGENT');
    if (envVal.isNotEmpty) return envVal;
    return _remoteOsmUserAgent ?? _defaultOsmUserAgent;
  }

  /// Called by [AppBootstrap] when Remote Config returns custom OSM configuration.
  static void setOsmConfig({
    String? tileUrl,
    String? userAgent,
  }) {
    if (tileUrl != null && tileUrl.isNotEmpty) {
      _remoteOsmTileUrl = tileUrl;
    }
    if (userAgent != null && userAgent.isNotEmpty) {
      _remoteOsmUserAgent = userAgent;
    }
  }
}
