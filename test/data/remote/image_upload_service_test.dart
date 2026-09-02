import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/data/remote/cloudinary_service.dart';
import 'package:cropguard_flutter/data/remote/supabase_storage_service.dart';
import 'package:cropguard_flutter/data/remote/image_upload_service.dart';
import 'package:cropguard_flutter/core/config/app_secrets.dart';
import 'package:cropguard_flutter/core/error/failures.dart';

class MockCloudinaryService extends Mock implements CloudinaryService {}

class MockSupabaseStorageService extends Mock
    implements SupabaseStorageService {}

void main() {
  late MockCloudinaryService mockCloudinary;
  late MockSupabaseStorageService mockSupabaseStorage;
  late ImageUploadService service;

  setUp(() {
    AppSecrets.reset();
    mockCloudinary = MockCloudinaryService();
    mockSupabaseStorage = MockSupabaseStorageService();
    service = ImageUploadService(mockCloudinary, mockSupabaseStorage);
  });

  tearDown(() {
    AppSecrets.reset();
  });

  test(
      'ImageUploadService falls back to Supabase Storage when Cloudinary is unconfigured',
      () async {
    when(() => mockSupabaseStorage.uploadCommunityImage(
          localPath: any(named: 'localPath'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => 'https://supabase.co/storage/sample.jpg');

    final result =
        await service.uploadImage('/tmp/test.jpg', userId: 'user123');

    expect(result, equals('https://supabase.co/storage/sample.jpg'));
    verify(() => mockSupabaseStorage.uploadCommunityImage(
          localPath: '/tmp/test.jpg',
          userId: 'user123',
        )).called(1);
    verifyNever(() => mockCloudinary.uploadImage(any()));
  });

  test(
      'ImageUploadService uses Cloudinary when configured and falls back to Supabase Storage on failure',
      () async {
    AppSecrets.dartDefineCloudinaryCloudNameOverride = 'test_cloud';
    AppSecrets.dartDefineCloudinaryUploadPresetOverride = 'test_preset';

    when(() => mockCloudinary.uploadImage(any()))
        .thenThrow(Exception('Cloudinary network error'));
    when(() => mockSupabaseStorage.uploadCommunityImage(
          localPath: any(named: 'localPath'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => 'https://supabase.co/storage/fallback.jpg');

    final result =
        await service.uploadImage('/tmp/test.jpg', userId: 'user123');

    expect(result, equals('https://supabase.co/storage/fallback.jpg'));
    verify(() => mockCloudinary.uploadImage('/tmp/test.jpg')).called(1);
    verify(() => mockSupabaseStorage.uploadCommunityImage(
          localPath: '/tmp/test.jpg',
          userId: 'user123',
        )).called(1);
  });

  test(
      'ImageUploadService cleans up temporary compressed file after successful upload',
      () async {
    final rawImage = img.Image(width: 2000, height: 1500);
    img.fill(rawImage, color: img.ColorRgb8(0, 128, 255));
    final jpgBytes = img.encodeJpg(rawImage, quality: 100);

    final tempDir = Directory.systemTemp;
    final testFile = File('${tempDir.path}/test_upload_large.jpg');
    await testFile.writeAsBytes(jpgBytes);

    String? uploadedPath;
    when(() => mockSupabaseStorage.uploadCommunityImage(
          localPath: any(named: 'localPath'),
          userId: any(named: 'userId'),
        )).thenAnswer((invocation) async {
      uploadedPath =
          invocation.namedArguments[const Symbol('localPath')] as String;
      expect(File(uploadedPath!).existsSync(), isTrue);
      return 'https://supabase.co/storage/uploaded.jpg';
    });

    try {
      final result =
          await service.uploadImage(testFile.path, userId: 'user123');

      expect(result, equals('https://supabase.co/storage/uploaded.jpg'));
      expect(uploadedPath, isNotNull);
      expect(uploadedPath, isNot(equals(testFile.path)));
      expect(File(uploadedPath!).existsSync(), isFalse);
      expect(await testFile.exists(), isTrue);
    } finally {
      if (await testFile.exists()) await testFile.delete();
      if (uploadedPath != null && await File(uploadedPath!).exists()) {
        await File(uploadedPath!).delete();
      }
    }
  });

  test(
      'ImageUploadService cleans up temporary compressed file even when upload fails',
      () async {
    final rawImage = img.Image(width: 2000, height: 1500);
    img.fill(rawImage, color: img.ColorRgb8(255, 0, 0));
    final jpgBytes = img.encodeJpg(rawImage, quality: 100);

    final tempDir = Directory.systemTemp;
    final testFile = File('${tempDir.path}/test_upload_fail.jpg');
    await testFile.writeAsBytes(jpgBytes);

    String? attemptedPath;
    when(() => mockSupabaseStorage.uploadCommunityImage(
          localPath: any(named: 'localPath'),
          userId: any(named: 'userId'),
        )).thenAnswer((invocation) {
      attemptedPath =
          invocation.namedArguments[const Symbol('localPath')] as String;
      throw Exception('Network upload failed');
    });

    try {
      await expectLater(
        () => service.uploadImage(testFile.path, userId: 'user123'),
        throwsA(isA<ServerFailure>()),
      );

      expect(attemptedPath, isNotNull);
      expect(attemptedPath, isNot(equals(testFile.path)));
      expect(File(attemptedPath!).existsSync(), isFalse);
      expect(await testFile.exists(), isTrue);
    } finally {
      if (await testFile.exists()) await testFile.delete();
      if (attemptedPath != null && await File(attemptedPath!).exists()) {
        await File(attemptedPath!).delete();
      }
    }
  });
}
