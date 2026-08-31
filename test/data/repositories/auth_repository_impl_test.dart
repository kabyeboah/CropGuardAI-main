import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/data/remote/firebase_auth_service.dart';
import 'package:cropguard_flutter/data/repositories/auth_repository_impl.dart';

class _MockFirebaseAuthService extends Mock implements FirebaseAuthService {}

class _MockUserCredential extends Mock
    implements firebase_auth.UserCredential {}

class _MockUser extends Mock implements firebase_auth.User {}

void main() {
  late _MockFirebaseAuthService mockAuthService;
  late AuthRepositoryImpl repository;
  late _MockUserCredential mockCredential;
  late _MockUser mockUser;

  setUp(() {
    mockAuthService = _MockFirebaseAuthService();
    repository = AuthRepositoryImpl(mockAuthService);
    mockCredential = _MockUserCredential();
    mockUser = _MockUser();

    when(() => mockCredential.user).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('user123');
    when(() => mockUser.email).thenReturn('farmer@example.com');
    when(() => mockUser.photoURL).thenReturn(null);
    when(() => mockUser.isAnonymous).thenReturn(false);
  });

  group('AuthRepositoryImpl.register', () {
    test('returns AppUser with updated display name when available', () async {
      when(() => mockUser.displayName).thenReturn('Kwame Mensah');
      when(() => mockAuthService.register(
            email: 'farmer@example.com',
            password: 'password123',
            name: 'Kwame Mensah',
          )).thenAnswer((_) async => mockCredential);

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
      // Simulate remote display name update being slow or not reflected yet on user object
      when(() => mockUser.displayName).thenReturn(null);
      when(() => mockAuthService.register(
            email: 'farmer@example.com',
            password: 'password123',
            name: 'Kwame Mensah',
          )).thenAnswer((_) async => mockCredential);

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
}
