import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/domain/models/app_user.dart';
import 'package:cropguard_flutter/domain/usecases/auth/register_usecase.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/remote/firebase_auth_service.dart';
import 'package:cropguard_flutter/presentation/screens/register/register_provider.dart';

class _MockRegisterUseCase extends Mock implements RegisterUseCase {}

class _MockDb extends Mock implements DatabaseHelper {}

class _MockAuthService extends Mock implements FirebaseAuthService {}

final _kUser = AppUser(
  id: 'u456',
  email: 'newuser@example.com',
  displayName: 'New User',
  isAnonymous: false,
);

void main() {
  late _MockRegisterUseCase mockRegisterUseCase;
  late _MockDb mockDb;
  late _MockAuthService mockAuth;
  late RegisterProvider provider;

  setUp(() {
    mockRegisterUseCase = _MockRegisterUseCase();
    mockDb = _MockDb();
    mockAuth = _MockAuthService();

    when(() => mockAuth.isAnonymous).thenReturn(false);

    provider = RegisterProvider(
      mockRegisterUseCase,
      mockDb,
      mockAuth,
    );
  });

  group('RegisterProvider - input validation', () {
    test('errors if any field is empty', () async {
      await provider.register(
        name: '',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'password123',
        termsAccepted: true,
        onSuccess: () {},
      );
      expect(provider.errorMessage, 'Please fill in all fields.');
    });

    test('errors if email is invalid', () async {
      await provider.register(
        name: 'Test',
        email: 'invalid-email',
        password: 'password123',
        confirmPassword: 'password123',
        termsAccepted: true,
        onSuccess: () {},
      );
      expect(provider.errorMessage, 'Please enter a valid email address.');
    });

    test('errors if passwords do not match', () async {
      await provider.register(
        name: 'Test',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'mismatch',
        termsAccepted: true,
        onSuccess: () {},
      );
      expect(provider.errorMessage, 'Passwords do not match.');
    });

    test('errors if terms not accepted', () async {
      await provider.register(
        name: 'Test',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'password123',
        termsAccepted: false,
        onSuccess: () {},
      );
      expect(
          provider.errorMessage, 'Please accept the terms and privacy policy.');
    });

    test('errors if password < 8 characters', () async {
      await provider.register(
        name: 'Test',
        email: 'test@example.com',
        password: '123',
        confirmPassword: '123',
        termsAccepted: true,
        onSuccess: () {},
      );
      expect(provider.errorMessage, 'Password must be at least 8 characters.');
    });
  });

  group('RegisterProvider - registration execution', () {
    test('successful registration updates status and calls onSuccess',
        () async {
      when(() => mockRegisterUseCase(
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          )).thenAnswer((_) async => Result.success(_kUser));

      bool successCalled = false;
      await provider.register(
        name: 'New User',
        email: 'newuser@example.com',
        password: 'password123',
        confirmPassword: 'password123',
        termsAccepted: true,
        onSuccess: () => successCalled = true,
      );

      expect(provider.status, RegisterStatus.success);
      expect(provider.errorMessage, isNull);
      expect(successCalled, isTrue);
    });

    test('failed registration maps failure message correctly', () async {
      when(() => mockRegisterUseCase(
                email: any(named: 'email'),
                password: any(named: 'password'),
                name: any(named: 'name'),
              ))
          .thenAnswer((_) async =>
              Result.error(const AuthFailure('email-already-in-use')));

      await provider.register(
        name: 'New User',
        email: 'newuser@example.com',
        password: 'password123',
        confirmPassword: 'password123',
        termsAccepted: true,
        onSuccess: () {},
      );

      expect(provider.status, RegisterStatus.error);
      expect(
          provider.errorMessage, 'An account already exists with that email.');
    });
  });
}
