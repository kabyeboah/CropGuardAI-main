import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/domain/usecases/auth/send_password_reset_usecase.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/presentation/screens/forgot_password/forgot_password_provider.dart';

class _MockAuthRepo extends Mock implements IAuthRepository {}

void main() {
  late _MockAuthRepo repo;
  late ForgotPasswordProvider provider;

  setUp(() {
    repo = _MockAuthRepo();
    provider = ForgotPasswordProvider(SendPasswordResetUseCase(repo));
  });

  tearDown(() => provider.dispose());

  group('ForgotPasswordProvider.send', () {
    test('sets error when email is invalid', () async {
      await provider.send('not-an-email');
      expect(provider.status, ForgotPasswordStatus.error);
      expect(provider.errorMessage, isNotNull);
    });

    test('sets success and sentEmail on valid send', () async {
      when(() => repo.sendPasswordReset(any()))
          .thenAnswer((_) async => Result.success(null));

      await provider.send('farmer@example.com');

      expect(provider.status, ForgotPasswordStatus.success);
      expect(provider.sentEmail, 'farmer@example.com');
      expect(provider.resendCooldown, greaterThan(0));
    });

    test('sets error status when repository fails', () async {
      when(() => repo.sendPasswordReset(any())).thenAnswer(
          (_) async => Result.error(const AuthFailure('user-not-found')));

      await provider.send('unknown@example.com');

      expect(provider.status, ForgotPasswordStatus.error);
      expect(provider.errorMessage, contains('No account found'));
    });

    test('maps too-many-requests to rate-limit message', () async {
      when(() => repo.sendPasswordReset(any())).thenAnswer(
          (_) async => Result.error(const AuthFailure('too-many-requests')));

      await provider.send('farmer@example.com');

      expect(provider.errorMessage, contains('Too many attempts'));
    });

    test('maps network failure to connection message', () async {
      when(() => repo.sendPasswordReset(any())).thenAnswer((_) async =>
          Result.error(const AuthFailure('network-request-failed')));

      await provider.send('farmer@example.com');

      expect(provider.errorMessage, contains('internet'));
    });

    test('trims whitespace from email before sending', () async {
      when(() => repo.sendPasswordReset(any()))
          .thenAnswer((_) async => Result.success(null));

      await provider.send('  farmer@example.com  ');

      verify(() => repo.sendPasswordReset('farmer@example.com')).called(1);
      expect(provider.sentEmail, 'farmer@example.com');
    });
  });
}
