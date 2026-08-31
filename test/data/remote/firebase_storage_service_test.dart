import 'dart:io';

import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/data/remote/firebase_storage_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

class MockReference extends Mock implements Reference {}

void main() {
  late MockFirebaseStorage mockStorage;
  late MockReference mockRootRef;
  late MockReference mockChildRef;
  late FirebaseStorageService service;
  late File testFile;

  setUpAll(() {
    registerFallbackValue(File(''));
  });

  setUp(() async {
    mockStorage = MockFirebaseStorage();
    mockRootRef = MockReference();
    mockChildRef = MockReference();

    when(() => mockStorage.ref()).thenReturn(mockRootRef);
    when(() => mockRootRef.child(any())).thenReturn(mockChildRef);

    service = FirebaseStorageService(storage: mockStorage);

    final tempDir = Directory.systemTemp;
    testFile = File(
        '${tempDir.path}/test_storage_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await testFile.writeAsString('test-image-content');
  });

  tearDown(() async {
    if (await testFile.exists()) {
      await testFile.delete();
    }
  });

  test('throws ServerFailure immediately if local file does not exist',
      () async {
    expect(
      () => service.uploadCommunityImage(
          localPath: '/non/existent/path.jpg', userId: 'user1'),
      throwsA(isA<ServerFailure>().having(
          (e) => e.message, 'message', contains('Image file not found'))),
    );
    verifyNever(() => mockStorage.ref());
  });

  test(
      'does not retry on permanent FirebaseException (permission-denied, unauthenticated)',
      () async {
    int attempts = 0;
    when(() => mockChildRef.putFile(any())).thenAnswer((_) {
      attempts++;
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'permission-denied',
        message: 'Missing permissions',
      );
    });

    await expectLater(
      () => service.uploadCommunityImage(
          localPath: testFile.path, userId: 'user1'),
      throwsA(isA<ServerFailure>()
          .having((e) => e.message, 'message', contains('permission-denied'))),
    );

    // Must fail fast on attempt 1 without retrying
    expect(attempts, equals(1));
    verify(() => mockChildRef.putFile(any())).called(1);
  });

  test('retries on transient FirebaseException (unavailable) up to maxAttempts',
      () async {
    int attempts = 0;
    when(() => mockChildRef.putFile(any())).thenAnswer((_) {
      attempts++;
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'unavailable',
        message: 'Service unavailable',
      );
    });

    await expectLater(
      () => service.uploadCommunityImage(
          localPath: testFile.path, userId: 'user1'),
      throwsA(isA<ServerFailure>()
          .having((e) => e.message, 'message', contains('unavailable'))),
    );

    // Retries 3 times before failing
    expect(attempts, equals(3));
    verify(() => mockChildRef.putFile(any())).called(3);
  });

  test('retries on transient SocketException up to maxAttempts', () async {
    int attempts = 0;
    when(() => mockChildRef.putFile(any())).thenAnswer((_) {
      attempts++;
      throw const SocketException('Connection reset by peer');
    });

    await expectLater(
      () => service.uploadCommunityImage(
          localPath: testFile.path, userId: 'user1'),
      throwsA(isA<ServerFailure>()
          .having((e) => e.message, 'message', contains('Connection reset'))),
    );

    expect(attempts, equals(3));
    verify(() => mockChildRef.putFile(any())).called(3);
  });
}
