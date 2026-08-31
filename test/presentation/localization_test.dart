import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'All four .arb files must have identical key sets and preserve ICU placeholders',
      () {
    final enFile = File('l10n/app_en.arb');
    final twFile = File('l10n/app_tw.arb');
    final eeFile = File('l10n/app_ee.arb');
    final dagFile = File('l10n/app_dag.arb');

    expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist');
    expect(twFile.existsSync(), isTrue, reason: 'app_tw.arb must exist');
    expect(eeFile.existsSync(), isTrue, reason: 'app_ee.arb must exist');
    expect(dagFile.existsSync(), isTrue, reason: 'app_dag.arb must exist');

    final enJson =
        jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
    final twJson =
        jsonDecode(twFile.readAsStringSync()) as Map<String, dynamic>;
    final eeJson =
        jsonDecode(eeFile.readAsStringSync()) as Map<String, dynamic>;
    final dagJson =
        jsonDecode(dagFile.readAsStringSync()) as Map<String, dynamic>;

    // Filter out @ metadata keys (e.g. @@locale, @treatmentAdvisoryDisclaimer)
    final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();
    final twKeys = twJson.keys.where((k) => !k.startsWith('@')).toSet();
    final eeKeys = eeJson.keys.where((k) => !k.startsWith('@')).toSet();
    final dagKeys = dagJson.keys.where((k) => !k.startsWith('@')).toSet();

    // Verify key sets are identical
    final twDiff = enKeys.difference(twKeys).union(twKeys.difference(enKeys));
    expect(twDiff, isEmpty,
        reason: 'Keys in app_tw.arb and app_en.arb mismatch: $twDiff');

    final eeDiff = enKeys.difference(eeKeys).union(eeKeys.difference(enKeys));
    expect(eeDiff, isEmpty,
        reason: 'Keys in app_ee.arb and app_en.arb mismatch: $eeDiff');

    final dagDiff =
        enKeys.difference(dagKeys).union(dagKeys.difference(enKeys));
    expect(dagDiff, isEmpty,
        reason: 'Keys in app_dag.arb and app_en.arb mismatch: $dagDiff');

    // Helper regex to extract placeholders like {name}
    final placeholderRegex = RegExp(r'\{([a-zA-Z0-9_]+)\}');

    void checkPlaceholders(String lang, Map<String, dynamic> jsonMap) {
      for (final entry in enJson.entries) {
        final key = entry.key;
        if (key.startsWith('@@') || key.startsWith('@')) continue;

        final enVal = entry.value;
        if (enVal is! String) continue;

        final locVal = jsonMap[key];
        if (locVal is! String) continue;

        final enPlaceholders =
            placeholderRegex.allMatches(enVal).map((m) => m.group(0)).toSet();
        final locPlaceholders =
            placeholderRegex.allMatches(locVal).map((m) => m.group(0)).toSet();

        expect(locPlaceholders, equals(enPlaceholders),
            reason:
                'ICU placeholders for key "$key" in app_$lang.arb must match English. '
                'English: $enPlaceholders, Localized: $locPlaceholders');
      }
    }

    checkPlaceholders('tw', twJson);
    checkPlaceholders('ee', eeJson);
    checkPlaceholders('dag', dagJson);
  });

  test('ARB files must not contain any duplicate top-level keys', () {
    final files = [
      'l10n/app_en.arb',
      'l10n/app_tw.arb',
      'l10n/app_ee.arb',
      'l10n/app_dag.arb'
    ];
    for (final path in files) {
      final text = File(path).readAsStringSync();
      final seenKeys = <String>{};
      final duplicates = <String>[];

      // Custom decoder logic to capture duplicates
      jsonDecode(
        text,
        reviver: (key, value) {
          if (key is String && !key.startsWith('@')) {
            // reviver is called for each property
          }
          return value;
        },
      );

      // Regex matching top level keys in JSON: `  "key":`
      final keyRegex = RegExp(r'^  "([a-zA-Z0-9_@]+)"\s*:', multiLine: true);
      for (final match in keyRegex.allMatches(text)) {
        final key = match.group(1)!;
        if (!seenKeys.add(key)) {
          duplicates.add(key);
        }
      }

      expect(duplicates, isEmpty,
          reason: '$path contains duplicate keys: $duplicates');
    }
  });
}
