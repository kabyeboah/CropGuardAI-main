class EmailValidator {
  static final _pattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static bool isValid(String email) {
    final trimmed = email.trim();
    return trimmed.isNotEmpty && _pattern.hasMatch(trimmed);
  }
}
