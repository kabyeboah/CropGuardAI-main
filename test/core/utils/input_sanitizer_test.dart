import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/input_sanitizer.dart';

void main() {
  group('InputSanitizer.sanitizeText', () {
    test('strips script tags and their content', () {
      const input = 'Hello <script>alert("xss")</script> world';
      // The script block is removed, then internal whitespace is normalized to
      // a single space (consistent with the "normalizes internal whitespace"
      // test below).
      expect(InputSanitizer.sanitizeText(input), 'Hello world');
    });

    test('strips arbitrary HTML tags', () {
      const input = '<b>Bold</b> and <div>div</div> text';
      expect(InputSanitizer.sanitizeText(input), 'Bold and div text');
    });

    test('removes inline event handlers with double quotes', () {
      const input = '<img onclick="steal()" src="x">';
      expect(InputSanitizer.sanitizeText(input), isNot(contains('onclick')));
    });

    test('removes javascript: protocol', () {
      const input = '<a href="javascript:void(0)">click</a>';
      expect(InputSanitizer.sanitizeText(input), isNot(contains('javascript')));
    });

    test('normalizes internal whitespace', () {
      const input = 'word1   word2\t\tword3';
      expect(InputSanitizer.sanitizeText(input), 'word1 word2 word3');
    });

    test('trims leading and trailing whitespace', () {
      expect(InputSanitizer.sanitizeText('  hello  '), 'hello');
    });

    test('returns empty string for empty input', () {
      expect(InputSanitizer.sanitizeText(''), '');
    });

    test('leaves plain text unchanged', () {
      const input = 'My tomato plant has yellow leaves.';
      expect(InputSanitizer.sanitizeText(input), input);
    });
  });

  group('InputSanitizer.plainText', () {
    test('truncates to maxLength', () {
      final result = InputSanitizer.plainText('A' * 600, 500);
      expect(result.length, 500);
    });

    test('does not truncate when under limit', () {
      const input = 'Short text';
      expect(InputSanitizer.plainText(input, 500), input);
    });

    test('sanitizes before truncating', () {
      const input = '<b>Hello</b>';
      final result = InputSanitizer.plainText(input, 3);
      expect(result, 'Hel');
    });
  });

  group('InputSanitizer.sanitizeTextForEditing', () {
    test('strips HTML tags without collapsing whitespace', () {
      const input = 'word1  <b>bold</b>  word2';
      final result = InputSanitizer.sanitizeTextForEditing(input);
      expect(result, contains('word1'));
      expect(result, isNot(contains('<b>')));
      // Internal spacing preserved (not collapsed to single space)
      expect(result, contains('  '));
    });
  });
}
