import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:cropguard_flutter/core/utils/image_safety_utils.dart';
import 'package:cropguard_flutter/core/utils/image_quality_analyzer.dart';
import 'package:cropguard_flutter/core/utils/image_compressor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageSafetyUtils & Real-World Formats', () {
    test('safely decodes and processes standard JPEG image', () {
      final baseImage = img.Image(width: 300, height: 300);
      for (var y = 0; y < 300; y++) {
        for (var x = 0; x < 300; x++) {
          final val = (x * 13 + y * 7) % 200 + 30;
          baseImage.setPixelRgb(x, y, (val + 20) % 255, (val + 60) % 255, val);
        }
      }
      final jpegBytes =
          Uint8List.fromList(img.encodeJpg(baseImage, quality: 90));

      final decoded = ImageSafetyUtils.safeDecodeAndOrient(jpegBytes);
      if (decoded == null) {
        fail('Expected decoded image not to be null');
      }
      expect(decoded.width, 300);
      expect(decoded.height, 300);

      final quality = ImageQualityAnalyzer.analyze(decoded);
      expect(quality.isAcceptable, isTrue);
    });

    test('safely decodes and processes PNG image with alpha channel', () {
      final pngImage = img.Image(width: 250, height: 250, numChannels: 4);
      for (var y = 0; y < 250; y++) {
        for (var x = 0; x < 250; x++) {
          pngImage.setPixelRgba(x, y, 90, 140, 70, 200);
        }
      }
      final pngBytes = Uint8List.fromList(img.encodePng(pngImage));

      final decoded = ImageSafetyUtils.safeDecodeAndOrient(pngBytes);
      if (decoded == null) {
        fail('Expected decoded image not to be null');
      }
      expect(decoded.width, 250);
      expect(decoded.height, 250);
    });

    test('safely decodes simulated screenshot with tall aspect ratio (PNG)',
        () {
      // Modern phone screenshot, e.g. 360 x 800
      final screenshot = img.Image(width: 360, height: 800);
      for (var y = 0; y < 800; y++) {
        for (var x = 0; x < 360; x++) {
          screenshot.setPixelRgb(x, y, 110, 160, 90);
        }
      }
      final screenshotBytes = Uint8List.fromList(img.encodePng(screenshot));

      final decoded = ImageSafetyUtils.safeDecodeAndOrient(screenshotBytes);
      if (decoded == null) {
        fail('Expected decoded image not to be null');
      }
      expect(decoded.width, 360);
      expect(decoded.height, 800);
    });

    test('safely decodes simulated WhatsApp image (highly compressed JPEG)',
        () {
      final waImage = img.Image(width: 400, height: 400);
      for (var y = 0; y < 400; y++) {
        for (var x = 0; x < 400; x++) {
          waImage.setPixelRgb(x, y, (x % 200) + 20, (y % 200) + 40, 60);
        }
      }
      // WhatsApp applies aggressive ~50% JPEG quality
      final waBytes = Uint8List.fromList(img.encodeJpg(waImage, quality: 50));

      final decoded = ImageSafetyUtils.safeDecodeAndOrient(waBytes);
      if (decoded == null) {
        fail('Expected decoded image not to be null');
      }
      expect(decoded.width, 400);
      expect(decoded.height, 400);
    });

    test(
        'bakes EXIF orientation tags so rotated images become canonically upright',
        () {
      // Create a 200x100 landscape image
      final imgOriginal = img.Image(width: 200, height: 100);
      for (var y = 0; y < 100; y++) {
        for (var x = 0; x < 200; x++) {
          imgOriginal.setPixelRgb(x, y, 120, 180, 70);
        }
      }
      // EXIF orientation 6 represents 90 deg CW rotation (portrait photo taken with landscape sensor)
      imgOriginal.exif.imageIfd.orientation = 6;

      final jpegBytes = Uint8List.fromList(img.encodeJpg(imgOriginal));
      final decodedAndOriented =
          ImageSafetyUtils.safeDecodeAndOrient(jpegBytes);

      if (decodedAndOriented == null) {
        fail('Expected decoded image not to be null');
      }
      // After orientation 6 is baked, width and height swap: 100 x 200
      expect(decodedAndOriented.width, 100);
      expect(decodedAndOriented.height, 200);
    });

    test(
        'handles tiny images by identifying tooSmall issue in ImageQualityAnalyzer',
        () {
      // 50x50 image (< 120px minimum)
      final tinyImg = img.Image(width: 50, height: 50);
      for (var y = 0; y < 50; y++) {
        for (var x = 0; x < 50; x++) {
          tinyImg.setPixelRgb(x, y, 100, 150, 80);
        }
      }
      final tinyBytes = Uint8List.fromList(img.encodeJpg(tinyImg));
      final decoded = ImageSafetyUtils.safeDecodeAndOrient(tinyBytes);

      if (decoded == null) {
        fail('Expected decoded image not to be null');
      }
      final quality = ImageQualityAnalyzer.analyze(decoded);
      expect(quality.isAcceptable, isFalse);
      expect(quality.issue, ImageQualityIssue.tooSmall);
    });

    test('handles corrupted or truncated file bytes safely without crashing',
        () {
      // Corrupt truncated JPEG header
      final corruptBytes =
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x77, 0x88]);
      final decoded = ImageSafetyUtils.safeDecodeAndOrient(corruptBytes);
      expect(decoded, isNull);

      // Empty byte array throws ImageCorruptException
      expect(
        () => ImageSafetyUtils.safeDecodeAndOrient(Uint8List(0)),
        throwsA(isA<ImageCorruptException>()),
      );
    });

    test('ImageCompressor safely resizes huge images to maxDimension bounds',
        () async {
      final hugeImg = img.Image(width: 2400, height: 1800);
      for (var y = 0; y < 1800; y += 10) {
        for (var x = 0; x < 2400; x += 10) {
          hugeImg.setPixelRgb(x, y, 80, 160, 60);
        }
      }
      final hugeBytes = Uint8List.fromList(img.encodeJpg(hugeImg, quality: 85));

      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/test_huge_input.jpg');
      await testFile.writeAsBytes(hugeBytes);

      final compressed = await ImageCompressor.compressImage(
        testFile,
        maxDimension: 1080,
        quality: 80,
      );

      expect(await compressed.exists(), isTrue);
      final compressedBytes = await compressed.readAsBytes();
      final decoded = img.decodeJpg(compressedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 1080);
      expect(decoded.height, 810);

      await testFile.delete();
      await compressed.delete();
    });

    test(
        'rejects decompression bombs with excessive dimensions or pixel counts',
        () {
      // Create an image object with dimensions exceeding 10,000 px limit
      final bombImage = img.Image(width: 10001, height: 500);
      final bytes = Uint8List.fromList(img.encodePng(bombImage));

      expect(
        () => ImageSafetyUtils.safeDecodeAndOrient(bytes),
        throwsA(isA<ImageBombException>()),
      );
    });

    test('rejects payload exceeding maxFileSizeBytes (25 MB)', () {
      // Dummy oversized buffer
      final oversizedBytes = Uint8List(26 * 1024 * 1024);
      expect(
        () => ImageSafetyUtils.safeDecodeAndOrient(oversizedBytes),
        throwsA(isA<ImageBombException>()),
      );
    });
  });
}
