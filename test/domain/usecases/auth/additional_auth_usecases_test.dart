import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/domain/usecases/auth/send_password_reset_usecase.dart';
import 'package:cropguard_flutter/domain/usecases/auth/signin_anonymously_usecase.dart';
import 'package:cropguard_flutter/domain/usecases/auth/signin_with_google_usecase.dart';

class _MockAuthRepo extends Mock implements IAuthRepository {}

void main() {
  late _MockAuthRepo repo;
  late SendPasswordResetUseCase sendReset;
  late SignInAnonymouslyUseCase signInAnon;
  late SignInWithGoogleUseCase signInGoogle;

  setUp(() {
    repo = _MockAuthRepo();
    sendReset = SendPasswordResetUseCase(repo);
    signInAnon = SignInAnonymouslyUseCase(repo);
    signInGoogle = SignInWithGoogleUseCase(repo);
  });

  // ── SendPasswordResetUseCase ──────────────────────────────────────────────

  group('SendPasswordResetUseCase', () {
    test('delegates to repository with the given email', () async {
      when(() => repo.sendPasswordReset(any()))
          .thenAnswer((_) async => Result.success(null));

      await sendReset('farmer@example.com');

      verify(() => repo.sendPasswordReset('farmer@example.com')).called(1);
    });

    test('returns success result from repository', () async {
      when(() => repo.sendPasswordReset(any()))
          .thenAnswer((_) async => Result.success(null));

      final result = await sendReset('test@example.com');

      expect(result.isSuccess, isTrue);
    });

    test('returns error result when repository fails', () async {
      when(() => repo.sendPasswordReset(any())).thenAnswer(
          (_) async => Result.error(const AuthFailure('User not found')));

      final result = await sendReset('noone@example.com');

      expect(result.isError, isTrue);
      expect(result.failure, isA<AuthFailure>());
    });
  });

  // ── SignInAnonymouslyUseCase ──────────────────────────────────────────────

  group('SignInAnonymouslyUseCase', () {
    test('delegates to repository', () async {
      when(() => repo.signInAnonymously())
          .thenAnswer((_) async => Result.success(null));

      await signInAnon();

      verify(() => repo.signInAnonymously()).called(1);
    });

    test('returns success when repository succeeds', () async {
      when(() => repo.signInAnonymously())
          .thenAnswer((_) async => Result.success(null));

      final result = await signInAnon();

      expect(result.isSuccess, isTrue);
    });

    test('returns error when repository fails', () async {
      when(() => repo.signInAnonymously()).thenAnswer((_) async =>
          Result.error(const AuthFailure('Anon sign-in disabled')));

      final result = await signInAnon();

      expect(result.isError, isTrue);
    });
  });

  // ── SignInWithGoogleUseCase ───────────────────────────────────────────────

  group('SignInWithGoogleUseCase', () {
    test('delegates to repository', () async {
      when(() => repo.signInWithGoogle())
          .thenAnswer((_) async => Result.success(null));

      await signInGoogle();

      verify(() => repo.signInWithGoogle()).called(1);
    });

    test('returns success when repository succeeds', () async {
      when(() => repo.signInWithGoogle())
          .thenAnswer((_) async => Result.success(null));

      final result = await signInGoogle();

      expect(result.isSuccess, isTrue);
    });

    test('returns error when Google sign-in fails', () async {
      when(() => repo.signInWithGoogle()).thenAnswer((_) async =>
          Result.error(const AuthFailure('Google sign-in cancelled')));

      final result = await signInGoogle();

      expect(result.isError, isTrue);
      expect(result.failure?.message, 'Google sign-in cancelled');
    });
  });
}
