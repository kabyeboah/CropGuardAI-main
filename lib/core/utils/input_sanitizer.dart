/// Utility responsible for sanitizing user-provided text input.
class InputSanitizer {
  /// Strips HTML and script tags and normalizes whitespace.
  static String sanitizeText(String input) {
    // Basic regex for scripts and tags
    var output = input.replaceAll(
      RegExp(r'<script\b[^<]*(?:(?!</script>)<[^<]*)*</script>',
          caseSensitive: false),
      '',
    );
    // Remove event handlers like onmouseover, onclick etc
    output = output.replaceAll(
      RegExp(r'\bon\w+\s*=\s*".*?"', caseSensitive: false),
      '',
    );
    output = output.replaceAll(
      RegExp(r'\bon\w+\s*=\s*\x27.*?\x27', caseSensitive: false),
      '',
    );
    output = output.replaceAll(
      RegExp(r'javascript:', caseSensitive: false),
      '',
    );
    
    final withoutTags = output.replaceAll(RegExp(r'<.*?>'), '');
    return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Removes scripts/tags without trimming or collapsing spaces.
  static String sanitizeTextForEditing(String input) {
    var output = input.replaceAll(
      RegExp(r'<script\b[^<]*(?:(?!</script>)<[^<]*)*</script>',
          caseSensitive: false),
      '',
    );
    return output.replaceAll(RegExp(r'<.*?>'), '');
  }

  static const int communityPostMax = 500;

  /// Sanitizes and truncates text to a maximum length.
  static String plainText(String input, int maxLength) {
    final sanitized = sanitizeText(input);
    if (sanitized.length > maxLength) {
      return sanitized.substring(0, maxLength);
    } else {
      return sanitized;
    }
  }

}
