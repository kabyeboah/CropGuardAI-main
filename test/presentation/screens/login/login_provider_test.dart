import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/domain/models/app_user.dart';
import 'package:cropguard_flutter/domain/usecases/auth/login_usecase.dart';
import 'package:cropguard_flutter/domain/usecases/auth/signin_with_google_usecase.dart';
import 'package:cropguard_flutter/domain/usecases/auth/signin_anonymously_usecase.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/remote/supabase_auth_service.dart';
import 'package:cropguard_flutter/core/utils/analytics_service.dart';
import 'package:cropguard_flutter/presentation/screens/login/login_provider.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockGoogleUseCase extends Mock implements SignInWithGoogleUseCase {}

class _MockGuestUseCase extends Mock implements SignInAnonymouslyUseCase {}

class _MockDb extends Mock implements DatabaseHelper {}

class _MockAuthService extends Mock implements SupabaseAuthService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

final _kUser = AppUser(
  id: 'u123',
  email: 'test@example.com',
  displayName: 'Test User',
  isAnonymous: false,
);

void main() {
  late _MockLoginUseCase mockLoginUseCase;
  late _MockGoogleUseCase mockGoogleUseCase;
  late _MockGuestUseCase mockGuestUseCase;
  late _MockDb mockDb;
  late _MockAuthService mockAuth;
  late _MockAnalyticsService mockAnalytics;
  late LoginProvider provider;

  setUp(() {
    mockLoginUseCase = _MockLoginUseCase();
    mockGoogleUseCase = _MockGoogleUseCase();
    mockGuestUseCase = _MockGuestUseCase();
    mockDb = _MockDb();
    mockAuth = _MockAuthService();
    mockAnalytics = _MockAnalyticsService();

    when(() => mockAuth.isAnonymous).thenReturn(false);
    when(() => mockAnalytics.logLogin(method: any(named: 'method')))
        .thenAnswer((_) async {});
    when(() => mockAnalytics.setUser(isAnonymous: any(named: 'isAnonymous')))
        .thenAnswer((_) async {});

    provider = LoginProvider(
      mockLoginUseCase,
      mockGoogleUseCase,
      mockGuestUseCase,
      mockDb,
      mockAuth,
      mockAnalytics,
    );
  });

  group('LoginProvider - validation & signIn', () {
    test('returns error message if email or password empty', () async {
      await provider.signIn('', '', () {});
      expect(provider.errorMessage, 'Please fill in all fields.');

      await provider.signIn('test@example.com', '', () {});
      expect(provider.errorMessage, 'Please fill in all fields.');
    });

    test('returns error message if email invalid', () async {
      await provider.signIn('invalid-email', 'password123', () {});
      expect(provider.errorMessage, 'Please enter a valid email address.');
    });

    test('successful email sign in calls onSuccess and sets status to success',
        () async {
      when(() => mockLoginUseCase(any(), any()))
          .thenAnswer((_) async => Result.success(_kUser));

      bool successCalled = false;
      await provider.signIn('test@example.com', 'password123', () {
        successCalled = true;
      });

      expect(provider.status, LoginStatus.success);
      expect(provider.errorMessage, isNull);
      expect(successCalled, isTrue);
    });

    test('failed email sign in sets status to error and maps failure message',
        () async {
      when(() => mockLoginUseCase(any(), any())).thenAnswer(
          (_) async => Result.error(const AuthFailure('wrong-password')));

      await provider.signIn('test@example.com', 'wrongpass', () {});

      expect(provider.status, LoginStatus.error);
      expect(provider.errorMessage, 'Incorrect email or password.');
    });
  });

  group('LoginProvider - signInWithGoogle', () {
    test('successful Google sign in updates status and calls onSuccess',
        () async {
      when(() => mockGoogleUseCase())
          .thenAnswer((_) async => Result.success(null));

      bool successCalled = false;
      await provider.signInWithGoogle(() {
        successCalled = true;
      });

      expect(provider.status, LoginStatus.success);
      expect(successCalled, isTrue);
    });

    test('failed Google sign in sets error state', () async {
      when(() => mockGoogleUseCase()).thenAnswer(
          (_) async => Result.error(const AuthFailure('google failure')));

      await provider.signInWithGoogle(() {});

      expect(provider.status, LoginStatus.error);
      expect(provider.errorMessage, 'google failure');
    });

    test('cancelled Google sign in sets cancelled error message', () async {
      when(() => mockGoogleUseCase()).thenAnswer(
          (_) async => Result.error(const AuthFailure('cancelled', code: 'cancelled')));

      await provider.signInWithGoogle(() {});

      expect(provider.status, LoginStatus.error);
      expect(provider.errorMessage, 'Google sign-in was cancelled.');
    });
  });

  group('LoginProvider - signInAsGuest', () {
    test('successful guest sign in updates status and calls onSuccess',
        () async {
      when(() => mockGuestUseCase())
          .thenAnswer((_) async => Result.success(null));

      bool successCalled = false;
      await provider.signInAsGuest(() {
        successCalled = true;
      });

      expect(provider.status, LoginStatus.success);
      expect(successCalled, isTrue);
    });

    test('failed guest sign in sets error state', () async {
      when(() => mockGuestUseCase()).thenAnswer(
          (_) async => Result.error(const AuthFailure('guest failure')));

      await provider.signInAsGuest(() {});

      expect(provider.status, LoginStatus.error);
      expect(provider.errorMessage, 'guest failure');
    });
  });
}
