import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:cropguard_flutter/core/utils/image_compressor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCompressor tests', () {
    test('compressImage resizes image exceeding maxDimension to ~1080px', () async {
      // Generate synthetic high-resolution image (2000 x 1500)
      final rawImage = img.Image(width: 2000, height: 1500);
      img.fill(rawImage, color: img.ColorRgb8(0, 128, 255));
      final jpgBytes = img.encodeJpg(rawImage, quality: 100);

      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/test_large_image.jpg');
      await testFile.writeAsBytes(jpgBytes);

      try {
        final compressedFile = await ImageCompressor.compressImage(
          testFile,
          maxDimension: 1080,
          quality: 80,
        );

        expect(await compressedFile.exists(), isTrue);
        final compressedBytes = await compressedFile.readAsBytes();
        final decodedCompressed = img.decodeImage(compressedBytes);

        expect(decodedCompressed, isNotNull);
        expect(decodedCompressed!.width, 1080);
        expect(decodedCompressed.height, 810);
        expect(compressedBytes.length, lessThan(jpgBytes.length));
      } finally {
        if (await testFile.exists()) await testFile.delete();
      }
    });

    test('compressImage returns original or valid compressed file for small images', () async {
      final rawImage = img.Image(width: 400, height: 300);
      img.fill(rawImage, color: img.ColorRgb8(255, 0, 0));
      final jpgBytes = img.encodeJpg(rawImage, quality: 90);

      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/test_small_image.jpg');
      await testFile.writeAsBytes(jpgBytes);

      try {
        final compressedFile = await ImageCompressor.compressImage(
          testFile,
          maxDimension: 1080,
          quality: 80,
        );

        expect(await compressedFile.exists(), isTrue);
        final compressedBytes = await compressedFile.readAsBytes();
        final decodedCompressed = img.decodeImage(compressedBytes);

        expect(decodedCompressed, isNotNull);
        expect(decodedCompressed!.width, 400);
        expect(decodedCompressed.height, 300);
      } finally {
        if (await testFile.exists()) await testFile.delete();
      }
    });

    test('cleanOldCompressedImages removes expired compressed files and retains newer ones', () async {
      final tempDir = Directory.systemTemp;
      final oldFile = File('${tempDir.path}/${ImageCompressor.tempFilePrefix}old_test.jpg');
      await oldFile.writeAsBytes([1, 2, 3]);
      // Set last modified date to 2 days ago
      await oldFile.setLastModified(DateTime.now().subtract(const Duration(days: 2)));

      final newFile = File('${tempDir.path}/${ImageCompressor.tempFilePrefix}new_test.jpg');
      await newFile.writeAsBytes([1, 2, 3]);

      try {
        expect(await oldFile.exists(), isTrue);
        expect(await newFile.exists(), isTrue);

        await ImageCompressor.cleanOldCompressedImages(maxAge: const Duration(hours: 24));

        expect(await oldFile.exists(), isFalse);
        expect(await newFile.exists(), isTrue);
      } finally {
        if (await oldFile.exists()) await oldFile.delete();
        if (await newFile.exists()) await newFile.delete();
      }
    });
  });
}
