import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/domain/usecases/auth/login_usecase.dart';
import 'package:cropguard_flutter/domain/models/app_user.dart';
import 'package:cropguard_flutter/core/utils/result.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late LoginUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = LoginUseCase(mockRepository);
  });

  final tUser = AppUser(
    id: '123',
    email: 'test@example.com',
    displayName: 'Test User',
    isAnonymous: false,
  );

  test('should return AppUser when login is successful', () async {
    // arrange
    when(() => mockRepository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => Result.success(tUser));

    // act
    final result = await useCase('test@example.com', 'password123');

    // assert
    expect(result.isSuccess, true);
    expect(result.data, tUser);
    verify(() => mockRepository.signIn(email: 'test@example.com', password: 'password123')).called(1);
  });
}
