import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/domain/usecases/auth/logout_usecase.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late LogoutUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = LogoutUseCase(mockRepository);
  });

  group('LogoutUseCase', () {
    test('returns success when sign-out succeeds', () async {
      when(() => mockRepository.signOut())
          .thenAnswer((_) async => Result.success(null));

      final result = await useCase();

      expect(result.isSuccess, true);
      verify(() => mockRepository.signOut()).called(1);
    });

    test('returns failure when sign-out throws', () async {
      when(() => mockRepository.signOut())
          .thenAnswer((_) async => Result.error(AuthFailure('network error')));

      final result = await useCase();

      expect(result.isError, true);
      expect(result.failure, isA<AuthFailure>());
    });

    test('delegates directly to repository with no transformation', () async {
      when(() => mockRepository.signOut())
          .thenAnswer((_) async => Result.success(null));

      await useCase();

      verify(() => mockRepository.signOut()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
