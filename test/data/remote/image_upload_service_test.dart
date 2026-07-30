import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/data/remote/cloudinary_service.dart';
import 'package:cropguard_flutter/data/remote/firebase_storage_service.dart';
import 'package:cropguard_flutter/data/remote/image_upload_service.dart';
import 'package:cropguard_flutter/core/config/app_secrets.dart';

class MockCloudinaryService extends Mock implements CloudinaryService {}
class MockFirebaseStorageService extends Mock implements FirebaseStorageService {}

void main() {
  late MockCloudinaryService mockCloudinary;
  late MockFirebaseStorageService mockFirebaseStorage;
  late ImageUploadService service;

  setUp(() {
    AppSecrets.reset();
    mockCloudinary = MockCloudinaryService();
    mockFirebaseStorage = MockFirebaseStorageService();
    service = ImageUploadService(mockCloudinary, mockFirebaseStorage);
  });

  tearDown(() {
    AppSecrets.reset();
  });

  test('ImageUploadService falls back to Firebase Storage when Cloudinary is unconfigured', () async {
    when(() => mockFirebaseStorage.uploadCommunityImage(
          localPath: any(named: 'localPath'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => 'https://firebase.storage/sample.jpg');

    final result = await service.uploadImage('/tmp/test.jpg', userId: 'user123');

    expect(result, equals('https://firebase.storage/sample.jpg'));
    verify(() => mockFirebaseStorage.uploadCommunityImage(
          localPath: '/tmp/test.jpg',
          userId: 'user123',
        )).called(1);
    verifyNever(() => mockCloudinary.uploadImage(any()));
  });

  test('ImageUploadService uses Cloudinary when configured and falls back to Firebase Storage on failure', () async {
    AppSecrets.dartDefineCloudinaryCloudNameOverride = 'test_cloud';
    AppSecrets.dartDefineCloudinaryUploadPresetOverride = 'test_preset';

    when(() => mockCloudinary.uploadImage(any())).thenThrow(Exception('Cloudinary network error'));
    when(() => mockFirebaseStorage.uploadCommunityImage(
          localPath: any(named: 'localPath'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => 'https://firebase.storage/fallback.jpg');

    final result = await service.uploadImage('/tmp/test.jpg', userId: 'user123');

    expect(result, equals('https://firebase.storage/fallback.jpg'));
    verify(() => mockCloudinary.uploadImage('/tmp/test.jpg')).called(1);
    verify(() => mockFirebaseStorage.uploadCommunityImage(
          localPath: '/tmp/test.jpg',
          userId: 'user123',
        )).called(1);
  });
}
