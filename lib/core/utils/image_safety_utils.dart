import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'app_logger.dart';

/// Exceptions related to image format safety and decompression bomb defense.
sealed class ImageSafetyException implements Exception {
  final String message;
  const ImageSafetyException(this.message);

  @override
  String toString() => message;
}

final class ImageBombException extends ImageSafetyException {
  const ImageBombException([
    super.message =
        'Image dimensions or uncompressed memory size exceeds safe limits (decompression bomb guard).',
  ]);
}

final class ImageCorruptException extends ImageSafetyException {
  const ImageCorruptException([
    super.message = 'Image file is corrupt, truncated, or unreadable.',
  ]);
}

/// Utility for safe image decoding, decompression bomb prevention,
/// and EXIF orientation baking.
class ImageSafetyUtils {
  ImageSafetyUtils._();

  /// Maximum allowed raw file size for ingestion (25 MB).
  static const int maxFileSizeBytes = 25 * 1024 * 1024;

  /// Maximum spatial dimension along any single axis (10,000 pixels).
  static const int maxDimensionPx = 10000;

  /// Maximum uncompressed pixel count (25 Megapixels = 25,000,000 pixels).
  /// Prevents decompression bombs (e.g., small 10KB PNGs expanding into 100MP bitmaps).
  static const int maxTotalPixels = 25000000;

  /// Safely decodes [bytes], guards against decompression bombs,
  /// and bakes EXIF orientation tags so the resulting image is canonically upright.
  static img.Image? safeDecodeAndOrient(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const ImageCorruptException('Image byte array is empty.');
    }

    if (bytes.length > maxFileSizeBytes) {
      throw ImageBombException(
        'Image file size (${bytes.length} bytes) exceeds maximum safety limit of $maxFileSizeBytes bytes.',
      );
    }

    // Decode image
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (e) {
      AppLogger.w('ImageSafetyUtils: img.decodeImage failed: $e');
      throw ImageCorruptException('Failed to decode image data: $e');
    }

    if (decoded == null) {
      return null;
    }

    // Verify bounds against decompression bomb attacks
    final width = decoded.width;
    final height = decoded.height;
    final totalPixels = width * height;

    if (width > maxDimensionPx ||
        height > maxDimensionPx ||
        totalPixels > maxTotalPixels) {
      throw ImageBombException(
        'Image dimensions (${width}x$height, $totalPixels pixels) exceed decompression bomb threshold (${maxDimensionPx}x$maxDimensionPx / $maxTotalPixels pixels).',
      );
    }

    // Bake EXIF orientation so rotated/mirrored images from camera/gallery are properly oriented
    try {
      final oriented = img.bakeOrientation(decoded);
      return oriented;
    } catch (e) {
      AppLogger.w(
          'ImageSafetyUtils: bakeOrientation failed ($e), using original decoded image');
      return decoded;
    }
  }

  /// Safely reads and decodes an image [file] with size and decompression checks.
  static Future<img.Image?> safeDecodeFile(File file) async {
    if (!await file.exists()) {
      throw ImageCorruptException('File not found: ${file.path}');
    }

    final stat = await file.stat();
    if (stat.size > maxFileSizeBytes) {
      throw ImageBombException(
        'File size (${stat.size} bytes) exceeds maximum limit of $maxFileSizeBytes bytes.',
      );
    }

    final bytes = await file.readAsBytes();
    return safeDecodeAndOrient(bytes);
  }
}
