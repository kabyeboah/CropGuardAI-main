import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:cropguard_flutter/core/utils/deep_link_service.dart';

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  late MockGoRouter mockRouter;
  late DeepLinkService service;

  setUp(() {
    mockRouter = MockGoRouter();
    service = DeepLinkService();
  });

  group('DeepLinkService - handleUri validation', () {
    test('routes to /reset_password with URL-encoded oobCode when URL is valid',
        () {
      final uri = Uri.parse(
          'https://cropguardai.app/reset-password?oobCode=safeCode123&mode=resetPassword');

      when(() => mockRouter.go(any())).thenReturn(null);

      service.handleUri(uri, mockRouter);

      verify(() => mockRouter.go('/reset_password?oobCode=safeCode123'))
          .called(1);
    });

    test('rejects deep links with invalid schemes (e.g. ftp)', () {
      final uri = Uri.parse(
          'ftp://cropguardai.app/reset-password?oobCode=safeCode123&mode=resetPassword');

      service.handleUri(uri, mockRouter);

      verifyNever(() => mockRouter.go(any()));
    });

    test('rejects deep links with unauthorized hostnames', () {
      final uri = Uri.parse(
          'https://malicious-domain.com/reset-password?oobCode=safeCode&mode=resetPassword');

      service.handleUri(uri, mockRouter);

      verifyNever(() => mockRouter.go(any()));
    });

    test(
        'rejects deep links with malicious query parameters containing injection payloads',
        () {
      final uri = Uri.parse(
          'https://cropguardai.app/reset-password?oobCode=../hack&mode=resetPassword');

      service.handleUri(uri, mockRouter);

      verifyNever(() => mockRouter.go(any()));
    });

    test('rejects deep links with malicious mode containing injection payloads',
        () {
      final uri = Uri.parse(
          'https://cropguardai.app/reset-password?oobCode=safeCode&mode=reset/Password');

      service.handleUri(uri, mockRouter);

      verifyNever(() => mockRouter.go(any()));
    });

    test('safely handles valid complex action codes', () {
      final uri = Uri.parse(
          'https://cropguardai.app/reset-password?oobCode=abc_123-xyz.123_456&mode=resetPassword');

      when(() => mockRouter.go(any())).thenReturn(null);

      service.handleUri(uri, mockRouter);

      verify(() => mockRouter.go('/reset_password?oobCode=abc_123-xyz.123_456'))
          .called(1);
    });

    test('intercepts io.supabase.cropguard OAuth callback deep link without crashing', () {
      final uri = Uri.parse(
          'io.supabase.cropguard://login-callback/#access_token=testToken&refresh_token=testRefresh');

      // Should handle gracefully
      service.handleUri(uri, mockRouter);
    });

    test('routes to /reset_password when custom scheme io.supabase.cropguard reset link is received', () {
      final uri = Uri.parse('io.supabase.cropguard://reset-password?code=safeCode123');

      when(() => mockRouter.go(any())).thenReturn(null);

      service.handleUri(uri, mockRouter);

      verify(() => mockRouter.go('/reset_password?oobCode=safeCode123')).called(1);
    });

    test('routes to /reset_password when custom scheme cropguard recovery link is received', () {
      final uri = Uri.parse('cropguard://reset-password#access_token=testToken&type=recovery');

      when(() => mockRouter.go(any())).thenReturn(null);

      service.handleUri(uri, mockRouter);

      verify(() => mockRouter.go('/reset_password?oobCode=')).called(1);
    });
  });
}
