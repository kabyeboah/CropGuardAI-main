import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/content_moderation_helper.dart';

void main() {
  group('ContentModerationHelper - Community Post Validation', () {
    test('accepts clean agricultural posts', () {
      final res = ContentModerationHelper.validateCommunityPost(
        'Applied copper spray on my cocoa farm today. Leaf spot seems under control.',
      );
      expect(res.isValid, isTrue);
      expect(res.flaggedReason, isNull);
    });

    test('rejects empty posts', () {
      final res = ContentModerationHelper.validateCommunityPost('   ');
      expect(res.isValid, isFalse);
      expect(res.flaggedReason, contains('empty'));
    });

    test('rejects posts exceeding 500 characters', () {
      final longText = 'A' * 501;
      final res = ContentModerationHelper.validateCommunityPost(longText);
      expect(res.isValid, isFalse);
      expect(res.flaggedReason, contains('500'));
    });

    test('rejects external URLs and phishing links', () {
      final res = ContentModerationHelper.validateCommunityPost(
        'Check out my website https://fake-agri-store.com for cheap seeds!',
      );
      expect(res.isValid, isFalse);
      expect(res.flaggedReason, contains('External links'));
    });

    test('rejects crypto/financial spam keywords', () {
      final res = ContentModerationHelper.validateCommunityPost(
        'Make free bitcoin fast! Double your money in 24 hours guaranteed return.',
      );
      expect(res.isValid, isFalse);
      expect(res.flaggedReason, contains('promotional spam'));
    });

    test('rejects casino and betting spam', () {
      final res = ContentModerationHelper.validateCommunityPost(
        'Best betting tips for today! Win cash now at casino jackpot.',
      );
      expect(res.isValid, isFalse);
      expect(res.flaggedReason, contains('promotional spam'));
    });

    test('rejects abusive language and profanity', () {
      final res = ContentModerationHelper.validateCommunityPost(
        'This app is bullshit and the users are idiots.',
      );
      expect(res.isValid, isFalse);
      expect(res.flaggedReason, contains('offensive or abusive'));
    });

    test('rejects local Ghanaian insults', () {
      final res = ContentModerationHelper.validateCommunityPost(
        'Wo yɛ kwasia on this farm.',
      );
      expect(res.isValid, isFalse);
      expect(res.flaggedReason, contains('offensive or abusive'));
    });

    test('rejects excessive character flooding and repetition', () {
      final res = ContentModerationHelper.validateCommunityPost(
        'Look at this leaf disease aaaaaaaaaaaaaaaaaa',
      );
      expect(res.isValid, isFalse);
      expect(res.flaggedReason, contains('repetitive'));
    });
  });

  group('ContentModerationHelper - Outbreak Notes & Report Reason', () {
    test('validateOutbreakNotes accepts valid agricultural notes', () {
      final res = ContentModerationHelper.validateOutbreakNotes(
          'Found multiple infested stems near boundary.');
      expect(res.isValid, isTrue);
    });

    test('validateOutbreakNotes rejects link spam', () {
      final res = ContentModerationHelper.validateOutbreakNotes(
          'Visit http://spam.xyz for cure');
      expect(res.isValid, isFalse);
      expect(res.flaggedReason, contains('External links'));
    });

    test('validateReportReason enforces 200 char max limit', () {
      final longReason = 'B' * 201;
      final res = ContentModerationHelper.validateReportReason(longReason);
      expect(res.isValid, isFalse);
      expect(res.flaggedReason, contains('200'));
    });
  });
}
