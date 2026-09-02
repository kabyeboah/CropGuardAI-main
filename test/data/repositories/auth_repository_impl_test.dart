import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/data/remote/supabase_auth_service.dart';
import 'package:cropguard_flutter/data/repositories/auth_repository_impl.dart';

class _MockSupabaseAuthService extends Mock implements SupabaseAuthService {}

class _MockAuthResponse extends Mock implements supabase.AuthResponse {}

class _MockUser extends Mock implements supabase.User {}

void main() {
  late _MockSupabaseAuthService mockAuthService;
  late AuthRepositoryImpl repository;
  late _MockAuthResponse mockResponse;
  late _MockUser mockUser;

  setUp(() {
    mockAuthService = _MockSupabaseAuthService();
    repository = AuthRepositoryImpl(mockAuthService);
    mockResponse = _MockAuthResponse();
    mockUser = _MockUser();

    when(() => mockResponse.user).thenReturn(mockUser);
    when(() => mockUser.id).thenReturn('user123');
    when(() => mockUser.email).thenReturn('farmer@example.com');
    when(() => mockUser.isAnonymous).thenReturn(false);
  });

  group('AuthRepositoryImpl.register', () {
    test('returns AppUser with updated display name when available', () async {
      when(() => mockUser.userMetadata).thenReturn({'full_name': 'Kwame Mensah'});
      when(() => mockAuthService.register(
            email: 'farmer@example.com',
            password: 'password123',
            name: 'Kwame Mensah',
          )).thenAnswer((_) async => mockResponse);

      final result = await repository.register(
        email: 'farmer@example.com',
        password: 'password123',
        name: 'Kwame Mensah',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.id, 'user123');
      expect(result.data?.displayName, 'Kwame Mensah');
      expect(result.data?.email, 'farmer@example.com');
    });

    test(
        'falls back to provided name if remote displayName is empty or default Farmer',
        () async {
      when(() => mockUser.userMetadata).thenReturn({});
      when(() => mockAuthService.register(
            email: 'farmer@example.com',
            password: 'password123',
            name: 'Kwame Mensah',
          )).thenAnswer((_) async => mockResponse);

      final result = await repository.register(
        email: 'farmer@example.com',
        password: 'password123',
        name: 'Kwame Mensah',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.id, 'user123');
      expect(result.data?.displayName, 'Kwame Mensah');
    });

    test('returns AuthFailure when authService throws', () async {
      when(() => mockAuthService.register(
            email: 'farmer@example.com',
            password: 'password123',
            name: 'Kwame Mensah',
          )).thenThrow(const AuthFailure('email-already-in-use'));

      final result = await repository.register(
        email: 'farmer@example.com',
        password: 'password123',
        name: 'Kwame Mensah',
      );

      expect(result.isError, isTrue);
      expect(result.failure, isA<AuthFailure>());
      expect(result.failure?.message, 'email-already-in-use');
    });
  });

  group('AuthRepositoryImpl.confirmPasswordReset & verifyPasswordResetCode', () {
    test('confirmPasswordReset succeeds when SupabaseAuthService succeeds', () async {
      when(() => mockAuthService.confirmPasswordReset(
            code: 'test-code',
            newPassword: 'NewPassword123!',
          )).thenAnswer((_) async {});

      final result = await repository.confirmPasswordReset(
        code: 'test-code',
        newPassword: 'NewPassword123!',
      );

      expect(result.isSuccess, isTrue);
      verify(() => mockAuthService.confirmPasswordReset(
            code: 'test-code',
            newPassword: 'NewPassword123!',
          )).called(1);
    });

    test('confirmPasswordReset returns failure when service throws', () async {
      when(() => mockAuthService.confirmPasswordReset(
            code: 'bad-code',
            newPassword: 'NewPassword123!',
          )).thenThrow(const AuthFailure('expired-code'));

      final result = await repository.confirmPasswordReset(
        code: 'bad-code',
        newPassword: 'NewPassword123!',
      );

      expect(result.isError, isTrue);
      expect(result.failure?.message, 'expired-code');
    });

    test('verifyPasswordResetCode succeeds when signed in or code valid', () async {
      when(() => mockAuthService.exchangeCodeForSession('valid-code'))
          .thenAnswer((_) async {});
      when(() => mockAuthService.isSignedIn).thenReturn(true);
      when(() => mockAuthService.currentUserEmail).thenReturn('farmer@example.com');

      final result = await repository.verifyPasswordResetCode('valid-code');

      expect(result.isSuccess, isTrue);
      expect(result.data, 'farmer@example.com');
    });

    test('verifyPasswordResetCode returns error on empty code when signed out', () async {
      when(() => mockAuthService.isSignedIn).thenReturn(false);

      final result = await repository.verifyPasswordResetCode('');

      expect(result.isError, isTrue);
      expect(result.failure?.message, contains('Invalid or expired'));
    });
  });
}

