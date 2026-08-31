import 'input_sanitizer.dart';

/// Result of a content moderation check.
class ModerationResult {
  final bool isValid;
  final String? flaggedReason;
  final String sanitizedText;

  const ModerationResult.valid(this.sanitizedText)
      : isValid = true,
        flaggedReason = null;

  const ModerationResult.flagged(this.flaggedReason, {this.sanitizedText = ''})
      : isValid = false;
}

/// Helper for client-side and server-side text moderation, spam filtering,
/// link detection, and character bound enforcement.
class ContentModerationHelper {
  ContentModerationHelper._();

  // Common spam & scam keywords/patterns
  static final List<RegExp> _spamPatterns = [
    RegExp(
        r'\b(free crypto|free bitcoin|forex trading|invest now|double your money|guaranteed return)\b',
        caseSensitive: false),
    RegExp(
        r'\b(whatsapp\s*me|dm\s*me\s*on\s*whatsapp|contact\s*me\s*at\s*(\+?\d{10,}))\b',
        caseSensitive: false),
    RegExp(
        r'\b(betting tips|casino|jackpot|free spin|win cash now|slot game)\b',
        caseSensitive: false),
    RegExp(r'\b(buy followers|telegram\s*channel|t\.me\/|wa\.me\/)\b',
        caseSensitive: false),
    RegExp(r'\b(discount viagra|cialis|pharmacy online)\b',
        caseSensitive: false),
  ];

  // Abusive language & harassment keywords (English & Ghanaian vulgarities)
  static final List<RegExp> _abusivePatterns = [
    RegExp(
        r'\b(fuck\w*|shit\w*|bullshit\w*|bitch\w*|bastard\w*|asshole\w*|idiot\w*|stupid\w*|dick\w*|cunt\w*)\b',
        caseSensitive: false),
    RegExp(r'\b(kwasia\w*|gyimie\w*|aboa\w*|kwasea\w*|kwasiafuo\w*)\b',
        caseSensitive: false), // Common Twi insults
  ];

  // Suspicious URLs or external link patterns not permitted in public community notes
  static final RegExp _urlPattern = RegExp(
    r'(https?:\/\/|www\.)[^\s/$.?#].[^\s]*',
    caseSensitive: false,
  );

  /// Validates community post text, ensuring it adheres to length limits,
  /// contains no prohibited spam keywords, no abusive terms, and no suspicious links.
  static ModerationResult validateCommunityPost(String input) {
    final sanitized = InputSanitizer.sanitizeText(input);

    if (sanitized.isEmpty) {
      return const ModerationResult.flagged('Post content cannot be empty.');
    }

    if (sanitized.length > InputSanitizer.communityPostMax) {
      return ModerationResult.flagged(
        'Post exceeds maximum character limit of ${InputSanitizer.communityPostMax} characters (${sanitized.length} characters).',
      );
    }

    return _checkContent(sanitized, allowLinks: false);
  }

  /// Validates outbreak report notes.
  static ModerationResult validateOutbreakNotes(String input) {
    if (input.trim().isEmpty) {
      return const ModerationResult.valid('');
    }

    final sanitized = InputSanitizer.sanitizeText(input);
    if (sanitized.length > InputSanitizer.outbreakNotesMax) {
      return const ModerationResult.flagged(
        'Outbreak notes exceed maximum length of ${InputSanitizer.outbreakNotesMax} characters.',
      );
    }

    return _checkContent(sanitized, allowLinks: false);
  }

  /// Validates abuse report reason text.
  static ModerationResult validateReportReason(String input) {
    final sanitized = InputSanitizer.sanitizeText(input);
    if (sanitized.length > InputSanitizer.reportReasonMax) {
      return const ModerationResult.flagged(
        'Report reason exceeds maximum limit of ${InputSanitizer.reportReasonMax} characters.',
      );
    }
    return ModerationResult.valid(sanitized);
  }

  /// Internal checker for spam, abuse, character flooding, and URLs.
  static ModerationResult _checkContent(String text,
      {bool allowLinks = false}) {
    // 1. Character repetition flood check (e.g. "aaaaaaa", "!!!!!!!")
    if (_hasExcessiveRepetition(text)) {
      return const ModerationResult.flagged(
        'Content contains excessive repetitive characters or spam patterns.',
      );
    }

    // 2. Link check
    if (!allowLinks && _urlPattern.hasMatch(text)) {
      return const ModerationResult.flagged(
        'External links and URLs are not permitted in community posts for security.',
      );
    }

    // 3. Spam patterns
    for (final pattern in _spamPatterns) {
      if (pattern.hasMatch(text)) {
        return const ModerationResult.flagged(
          'Content flagged as promotional spam or prohibited advertising.',
        );
      }
    }

    // 4. Abusive language
    for (final pattern in _abusivePatterns) {
      if (pattern.hasMatch(text)) {
        return const ModerationResult.flagged(
          'Content contains offensive or abusive language.',
        );
      }
    }

    return ModerationResult.valid(text);
  }

  /// Detects whether text has 6+ consecutive identical characters or identical words repeated 4+ times.
  static bool _hasExcessiveRepetition(String text) {
    // 6 or more identical characters in a row (e.g. "aaaaaa", "!!!!!!")
    final charRepeat = RegExp(r'(.)\1{5,}');
    if (charRepeat.hasMatch(text)) return true;

    // Word repeated 4 or more times consecutively
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    if (words.length >= 4) {
      int consecutive = 1;
      for (int i = 1; i < words.length; i++) {
        if (words[i] == words[i - 1] && words[i].isNotEmpty) {
          consecutive++;
          if (consecutive >= 4) return true;
        } else {
          consecutive = 1;
        }
      }
    }

    return false;
  }
}
