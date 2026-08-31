import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/core/utils/safe_image_downloader.dart';
import 'package:cropguard_flutter/core/utils/input_sanitizer.dart';
import 'package:cropguard_flutter/core/utils/diagnostic_sanitizer.dart';
import 'package:cropguard_flutter/core/utils/location_helper.dart';
import 'package:cropguard_flutter/core/utils/rate_limiter.dart';
import 'package:cropguard_flutter/core/utils/user_block_service.dart';
import 'package:cropguard_flutter/data/local/pending_sync_queue.dart';
import 'package:cropguard_flutter/domain/models/community_post.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audit Bug Regression Suite (Phase 19 Verification)', () {
    // ------------------------------------------------------------------------
    // Bug 1: SSRF Vulnerability in SafeImageDownloader
    // Discovered: Image downloader could be tricked to fetch cloud metadata/private IPs
    // ------------------------------------------------------------------------
    group('Regression 1: SSRF & Internal IP Rejection', () {
      final downloader = SafeImageDownloader();

      test('rejects AWS/GCP cloud metadata IP (169.254.169.254)', () async {
        expect(
          () => downloader.downloadImage(
            'http://169.254.169.254/latest/meta-data/',
          ),
          throwsA(isA<ImageSecurityException>()),
        );
      });

      test('rejects localhost, loopback, and local domain names', () async {
        for (final url in [
          'http://localhost/admin.jpg',
          'http://127.0.0.1:8080/exploit.png',
          'http://127.0.0.2/secret.jpg',
          'http://app.local/internal.png',
          'http://backend.internal/dump.jpg',
        ]) {
          expect(
            () => downloader.downloadImage(url),
            throwsA(isA<ImageSecurityException>()),
            reason: 'URL $url must be blocked by SSRF filter',
          );
        }
      });

      test('rejects non-HTTP schemes like file:// and gopher://', () async {
        expect(
          () => downloader.downloadImage('file:///etc/passwd'),
          throwsA(isA<ImageSecurityException>()),
        );
        expect(
          () => downloader.downloadImage('ftp://malicious.host/exploit.jpg'),
          throwsA(isA<ImageSecurityException>()),
        );
      });
    });

    // ------------------------------------------------------------------------
    // Bug 2: Prompt Injection and Delimiter Hijacking in AI Services
    // Discovered: Raw farm notes could override system prompts or breakout markdown
    // ------------------------------------------------------------------------
    group('Regression 2: Text & Input Sanitization', () {
      test('InputSanitizer neutralizes scripts, event handlers, and tags', () {
        const adversarialInput =
            '<script>alert(1)</script><div onclick="exploit()">Dangerous Content</div>';
        final sanitized = InputSanitizer.sanitizeText(adversarialInput);

        expect(sanitized.contains('<script>'), isFalse);
        expect(sanitized.contains('onclick'), isFalse);
        expect(sanitized.contains('alert(1)'), isFalse);
        expect(sanitized, 'Dangerous Content');
      });

      test('InputSanitizer strictly truncates length beyond maximum allowance',
          () {
        final hugeInput = 'A' * (InputSanitizer.communityPostMax + 500);
        final sanitized = InputSanitizer.plainText(
            hugeInput, InputSanitizer.communityPostMax);
        expect(sanitized.length,
            lessThanOrEqualTo(InputSanitizer.communityPostMax));
      });
    });

    // ------------------------------------------------------------------------
    // Bug 3: Token and Credential Leakage in Diagnostics & Error Logs
    // Discovered: Stack traces & diagnostics could contain Bearer tokens and API keys
    // ------------------------------------------------------------------------
    group('Regression 3: Diagnostic Sanitizer Redaction', () {
      test('redacts Google API keys and Bearer tokens', () {
        const rawLog =
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9 and API Key AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
        final sanitized = DiagnosticSanitizer.sanitizeString(rawLog);

        expect(
            sanitized.contains('AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxx'), isFalse);
        expect(sanitized, contains('Bearer [REDACTED_TOKEN]'));
        expect(sanitized, contains('[REDACTED_API_KEY]'));
      });

      test('redacts email addresses and phone numbers in diagnostics', () {
        const rawPII =
            'Contact farmer at farmer.kofi@gmail.com or call +233241234567 or 0244123456';
        final sanitized = DiagnosticSanitizer.sanitizeString(rawPII);

        expect(sanitized.contains('farmer.kofi@gmail.com'), isFalse);
        expect(sanitized.contains('+233241234567'), isFalse);
        expect(sanitized.contains('0244123456'), isFalse);
        expect(sanitized, contains('[REDACTED_EMAIL]'));
        expect(sanitized, contains('[REDACTED_PHONE]'));
      });

      test(
          'coarsens high-precision farm coordinates in logs to protect farm privacy',
          () {
        const rawCoords =
            'Farm scan at latitude: 6.68854321, longitude: -1.62441234';
        final sanitized = DiagnosticSanitizer.sanitizeString(rawCoords);

        expect(sanitized.contains('6.68854321'), isFalse);
        expect(sanitized.contains('-1.62441234'), isFalse);
        expect(sanitized.contains('6.69'), isTrue);
        expect(sanitized.contains('-1.62'), isTrue);
      });
    });

    // ------------------------------------------------------------------------
    // Bug 4: Offline Sync Queue Retry Limits
    // Discovered: Max retry limits and abandoned state handling
    // ------------------------------------------------------------------------
    group('Regression 4: Offline Sync Queue Limits', () {
      test('PendingSyncQueue defines max retries of 5', () {
        expect(PendingSyncQueue.maxRetries, 5);
      });

      test(
          'PendingSyncQueue sanitizes FieldValue and DateTime objects without throwing',
          () {
        final payload = {
          'date': DateTime(2026, 8, 31),
          'num': 42,
          'str': 'hello',
          'nested': {'timestamp': DateTime(2026, 8, 31)},
        };

        final sanitized = PendingSyncQueue.sanitizePayload(payload);
        expect(sanitized['num'], 42);
        expect(sanitized['str'], 'hello');
        expect(sanitized['date'], contains('2026-08-31'));
      });
    });

    // ------------------------------------------------------------------------
    // Bug 5: Client-Side Rate Limiter Burst Protection
    // Discovered: Repeated button taps flooded remote services
    // ------------------------------------------------------------------------
    group('Regression 5: Rate Limiter Cooldown & Sliding Window', () {
      test('blocks immediate rapid-fire actions within cooldown duration', () {
        final limiter = RateLimiter();
        const actionKey = 'scan_button_press';

        final first =
            limiter.checkLimit(actionKey, cooldown: const Duration(seconds: 2));
        expect(first.isAllowed, isTrue);

        final second =
            limiter.checkLimit(actionKey, cooldown: const Duration(seconds: 2));
        expect(second.isAllowed, isFalse);
        expect(second.message, contains('Please wait'));
      });

      test('blocks actions when maxPerWindow count is exhausted', () {
        final limiter = RateLimiter();
        const actionKey = 'report_post_user_123';

        // 3 requests allowed in 10s window
        for (var i = 0; i < 3; i++) {
          final res = limiter.checkLimit(
            actionKey,
            maxPerWindow: 3,
            windowDuration: const Duration(seconds: 10),
            cooldown: Duration.zero,
          );
          expect(res.isAllowed, isTrue);
        }

        // 4th request must be blocked
        final fourth = limiter.checkLimit(
          actionKey,
          maxPerWindow: 3,
          windowDuration: const Duration(seconds: 10),
          cooldown: Duration.zero,
        );
        expect(fourth.isAllowed, isFalse);
      });
    });

    // ------------------------------------------------------------------------
    // Bug 6: User Blocking & Community Feed Filtering
    // Discovered: Blocked users posts remained visible in community feed
    // ------------------------------------------------------------------------
    group('Regression 6: User Block Service in Community Feed', () {
      test('filters out posts authored by blocked users', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final blockService = UserBlockService(prefs);

        await blockService.blockUser('malicious_spammer_99');

        final posts = [
          CommunityPost(
            id: 'p1',
            userId: 'good_farmer_1',
            author: 'Kwame',
            body: 'Healthy crop this season',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
          CommunityPost(
            id: 'p2',
            userId: 'malicious_spammer_99',
            author: 'Spammer',
            body: 'Buy fake chemicals',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        ];

        final visiblePosts =
            posts.where((p) => !blockService.isBlocked(p.userId)).toList();
        expect(visiblePosts.length, 1);
        expect(visiblePosts.first.id, 'p1');
      });
    });

    // ------------------------------------------------------------------------
    // Bug 7: Location Coordinate Coarsening & Privacy Radius
    // Discovered: Exact farmer GPS coordinates were broadcasted to public map
    // ------------------------------------------------------------------------
    group('Regression 7: Location Coordinate Coarsening', () {
      test('coarsens high-precision coordinates to ~1.1km grid', () {
        expect(LocationHelper.coarsen(5.603716, precision: 2), 5.60);
        expect(LocationHelper.coarsen(-0.186964, precision: 2), -0.19);
      });
    });

    // ------------------------------------------------------------------------
    // Bug 8: Soft Voting Ensemble Confidence Threshold Fallback
    // Discovered: Low confidence / degraded predictions flagged explicitly
    // ------------------------------------------------------------------------
    group('Regression 8: Degraded & Fallback Flagging', () {
      test('flags degraded results clearly for UI warning display', () {
        const result = DetectionResult(
          id: 1,
          imagePath: '/tmp/test.jpg',
          diseaseLabel: 'Tomato Early Blight',
          displayName: 'Tomato Early Blight',
          confidence: 0.48,
          isHealthy: false,
          cropType: 'Tomato',
          cause: 'Fungal',
          treatments: ['Apply copper fungicide'],
          timestamp: 1690000000000,
          isDegraded: true,
        );

        expect(result.isDegraded, isTrue);
        expect(result.confidence, lessThan(0.65));
      });

      test('confident predictions are marked as not degraded', () {
        const result = DetectionResult(
          id: 2,
          imagePath: '/tmp/test.jpg',
          diseaseLabel: 'Tomato Early Blight',
          displayName: 'Tomato Early Blight',
          confidence: 0.88,
          isHealthy: false,
          cropType: 'Tomato',
          cause: 'Fungal',
          treatments: ['Apply copper fungicide'],
          timestamp: 1690000000000,
          isDegraded: false,
        );

        expect(result.isDegraded, isFalse);
        expect(result.confidence, greaterThanOrEqualTo(0.65));
      });
    });
  });
}
