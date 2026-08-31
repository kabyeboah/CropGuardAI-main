/// Khaya AI Language Configuration — CropGuard authoritative mapping.
///
/// This file is the single source of truth for:
///   - API version constants
///   - CropGuard locale -> Khaya provider code mapping
///   - Per-language feature support flags
///   - TTS speaker IDs
///
/// Any change to language codes or API versions MUST be reflected here
/// AND in docs/api/KHAYA_API_CONTRACT.md.
library;

// ── API Version Config ─────────────────────────────────────────────────────

/// Centralised Khaya AI API version configuration.
/// NEVER reference deprecated versions (ASR v1/v2, TTS v1, Translation v1) in code.
class KhayaApiConfig {
  KhayaApiConfig._();

  // Base URL for direct client calls (local dev only — production goes via backend)
  static const String baseUrl = 'https://translation-api.ghananlp.org';

  // API Versions — change here to migrate across the entire app
  static const String asrVersion = 'v3';          // ASR v1, v2 are DEPRECATED
  static const String ttsVersion = 'v2';          // TTS v1 is DEPRECATED
  static const String translationVersion = 'v2';  // Translation v1 is DEPRECATED

  // Timeouts
  static const Duration asrTimeout = Duration(seconds: 15);
  static const Duration ttsTimeout = Duration(seconds: 20);
  static const Duration translationTimeout = Duration(seconds: 10);

  // Retry policy
  static const int maxRetryAttempts = 3;

  // Max text length for TTS (enforced server-side too)
  static const int maxTtsTextLength = 2000;
}

// ── Per-Language Configuration ─────────────────────────────────────────────

/// Configuration for a single language in CropGuard's Ghanaian language services.
class KhayaLanguageConfig {
  final String cropGuardLocale;
  final String displayName;
  final String providerCode;
  final String? ttsSpeakerId;
  final bool asrSupported;
  final bool ttsSupported;
  final bool translationSupported;

  const KhayaLanguageConfig({
    required this.cropGuardLocale,
    required this.displayName,
    required this.providerCode,
    this.ttsSpeakerId,
    required this.asrSupported,
    required this.ttsSupported,
    required this.translationSupported,
  });

  /// Returns the language pair for translation from this language to English.
  String get toEnglishPair => '$providerCode-en';

  /// Returns the language pair for translation from English to this language.
  String get fromEnglishPair => 'en-$providerCode';
}

// ── Language Registry ──────────────────────────────────────────────────────

/// The authoritative mapping of CropGuard locales to Khaya AI provider codes.
///
/// Source of truth: docs/api/KHAYA_API_CONTRACT.md
/// Unverified entries are marked with a comment — verify from developer.khaya.ai.
class KhayaLanguageRegistry {
  KhayaLanguageRegistry._();

  /// All registered language configurations.
  static const List<KhayaLanguageConfig> all = [
    // Twi — fully verified
    KhayaLanguageConfig(
      cropGuardLocale: 'tw',
      displayName: 'Twi',
      providerCode: 'tw',
      ttsSpeakerId: 'twi_speaker_4',
      asrSupported: true,
      ttsSupported: true,
      translationSupported: true,
    ),
    // Ewe — fully verified
    KhayaLanguageConfig(
      cropGuardLocale: 'ee',
      displayName: 'Ewe',
      providerCode: 'ee',
      ttsSpeakerId: 'ewe_speaker_1',
      asrSupported: true,
      ttsSupported: true,
      translationSupported: true,
    ),
    // Dagbani — fully verified
    KhayaLanguageConfig(
      cropGuardLocale: 'dag',
      displayName: 'Dagbani',
      providerCode: 'dag',
      ttsSpeakerId: 'dagbani_speaker_1',
      asrSupported: true,
      ttsSupported: true,
      translationSupported: true,
    ),
    // Ga — UNVERIFIED (query developer.khaya.ai for speaker_id + support flags)
    KhayaLanguageConfig(
      cropGuardLocale: 'gaa',
      displayName: 'Ga',
      providerCode: 'gaa',
      ttsSpeakerId: null, // UNVERIFIED
      asrSupported: false,
      ttsSupported: false,
      translationSupported: false,
    ),
    // Fante — UNVERIFIED (query developer.khaya.ai for speaker_id + support flags)
    KhayaLanguageConfig(
      cropGuardLocale: 'fat',
      displayName: 'Fante',
      providerCode: 'fat',
      ttsSpeakerId: null, // UNVERIFIED
      asrSupported: false,
      ttsSupported: false,
      translationSupported: false,
    ),
  ];

  /// All languages verified to support ASR.
  static List<KhayaLanguageConfig> get asrSupported =>
      all.where((l) => l.asrSupported).toList();

  /// All languages verified to support TTS.
  static List<KhayaLanguageConfig> get ttsSupported =>
      all.where((l) => l.ttsSupported).toList();

  /// All languages verified to support Translation.
  static List<KhayaLanguageConfig> get translationSupported =>
      all.where((l) => l.translationSupported).toList();

  /// Looks up config by CropGuard locale. Returns null if not registered.
  static KhayaLanguageConfig? byLocale(String locale) {
    try {
      return all.firstWhere((l) => l.cropGuardLocale == locale);
    } catch (_) {
      return null;
    }
  }

  /// Looks up config by Khaya provider code. Returns null if not found.
  static KhayaLanguageConfig? byProviderCode(String code) {
    try {
      return all.firstWhere((l) => l.providerCode == code);
    } catch (_) {
      return null;
    }
  }

  /// Returns true if [locale] supports ASR according to verified data.
  static bool supportsAsr(String locale) =>
      byLocale(locale)?.asrSupported ?? false;

  /// Returns true if [locale] supports TTS according to verified data.
  static bool supportsTts(String locale) =>
      byLocale(locale)?.ttsSupported ?? false;

  /// Returns true if [locale] supports Translation according to verified data.
  static bool supportsTranslation(String locale) =>
      byLocale(locale)?.translationSupported ?? false;
}
