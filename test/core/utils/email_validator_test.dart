import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/email_validator.dart';

void main() {
  group('EmailValidator.isValid', () {
    group('valid addresses', () {
      final valid = [
        'farmer@example.com',
        'kofi.mensah@domain.org',
        'user+tag@sub.domain.co.uk',
        'a@b.io',
        '  spaced@example.com  ', // trimmed before check
      ];

      for (final email in valid) {
        test('"$email" is valid', () {
          expect(EmailValidator.isValid(email), true);
        });
      }
    });

    group('invalid addresses', () {
      final invalid = [
        '',
        '   ',
        'notanemail',
        '@nodomain.com',
        'missing@',
        'missing@domain',
        'two@@domain.com',
        'space in@domain.com',
      ];

      for (final email in invalid) {
        test('"$email" is invalid', () {
          expect(EmailValidator.isValid(email), false);
        });
      }
    });
  });
}
