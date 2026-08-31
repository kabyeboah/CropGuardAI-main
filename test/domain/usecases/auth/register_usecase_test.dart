import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/domain/models/app_user.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/domain/usecases/auth/register_usecase.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late RegisterUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = RegisterUseCase(mockRepository);
  });

  final tUser = AppUser(
    id: 'abc',
    email: 'farmer@example.com',
    displayName: 'Kofi Mensah',
    isAnonymous: false,
  );

  group('RegisterUseCase', () {
    test('returns AppUser on successful registration', () async {
      when(() => mockRepository.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          )).thenAnswer((_) async => Result.success(tUser));

      final result = await useCase(
        email: 'farmer@example.com',
        password: 'password123',
        name: 'Kofi Mensah',
      );

      expect(result.isSuccess, true);
      expect(result.data, tUser);
      verify(() => mockRepository.register(
            email: 'farmer@example.com',
            password: 'password123',
            name: 'Kofi Mensah',
          )).called(1);
    });

    test('returns failure when email is already in use', () async {
      when(() => mockRepository.register(
                email: any(named: 'email'),
                password: any(named: 'password'),
                name: any(named: 'name'),
              ))
          .thenAnswer((_) async =>
              Result.error(const AuthFailure('email-already-in-use')));

      final result = await useCase(
        email: 'taken@example.com',
        password: 'password123',
        name: 'Kofi',
      );

      expect(result.isError, true);
      expect(result.failure!.message, contains('email-already-in-use'));
    });

    test('passes arguments through to repository unchanged', () async {
      when(() => mockRepository.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          )).thenAnswer((_) async => Result.success(tUser));

      await useCase(email: 'a@b.com', password: 'secret123', name: 'Ama');

      verify(() => mockRepository.register(
            email: 'a@b.com',
            password: 'secret123',
            name: 'Ama',
          )).called(1);
    });

    test('returns failure when password is less than 8 characters', () async {
      final result = await useCase(
        email: 'test@example.com',
        password: 'short',
        name: 'Kofi',
      );

      expect(result.isError, true);
      expect(result.failure!.message,
          'Password must be at least 8 characters long.');
      verifyNever(() => mockRepository.register(
            email: any(named: 'email'),
            password: any(named: 'password'),
            name: any(named: 'name'),
          ));
    });
  });
}
