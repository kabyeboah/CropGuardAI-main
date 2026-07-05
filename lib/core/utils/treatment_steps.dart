/// Splits a treatment paragraph into up to [maxSteps] steps for UI display.
class TreatmentSteps {
  static List<String> splitIntoSteps(String text, {int maxSteps = 4}) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return [];

    // Split by sentences
    final sentences = cleaned
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 12)
        .toList();

    if (sentences.length >= 2) {
      return sentences.take(maxSteps).toList();
    }

    // Fallback to semicolon split
    final parts = cleaned
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return parts.take(maxSteps).toList();
    }

    return [cleaned];
  }
}
