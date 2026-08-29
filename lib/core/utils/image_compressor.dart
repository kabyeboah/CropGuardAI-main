import 'dart:io';

import 'package:image/image.dart' as img;

import 'app_logger.dart';

/// Utility to compress camera and gallery images before network upload.
/// Resizes image so long edge is ~1080px at ~80% JPEG quality.
class ImageCompressor {
  ImageCompressor._();

  static const String tempFilePrefix = 'cropguard_compressed_';

  static Future<File> compressImage(
    File file, {
    int maxDimension = 1080,
    int quality = 80,
  }) async {
    try {
      if (!await file.exists()) return file;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return file;

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        AppLogger.w('ImageCompressor: Unable to decode image at ${file.path}');
        return file;
      }

      img.Image processed = decoded;
      final width = decoded.width;
      final height = decoded.height;

      if (width > maxDimension || height > maxDimension) {
        if (width >= height) {
          processed = img.copyResize(decoded, width: maxDimension);
        } else {
          processed = img.copyResize(decoded, height: maxDimension);
        }
      }

      final compressedBytes = img.encodeJpg(processed, quality: quality);

      final tempDir = Directory.systemTemp;
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile =
          File('${tempDir.path}/$tempFilePrefix$timeStamp.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      AppLogger.i(
        'ImageCompressor: Compressed (${bytes.length} bytes -> ${compressedBytes.length} bytes, '
        '${width}x$height -> ${processed.width}x${processed.height})',
      );
      return compressedFile;
    } catch (e) {
      AppLogger.w('ImageCompressor: Compression failed ($e), using original file');
      return file;
    }
  }

  /// Cleans up any leftover compressed images from the temp directory that are older than [maxAge].
  static Future<void> cleanOldCompressedImages({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    try {
      final tempDir = Directory.systemTemp;
      if (!await tempDir.exists()) return;

      final now = DateTime.now();
      await for (final entity in tempDir.list()) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : entity.path;
          if (fileName.startsWith(tempFilePrefix) && fileName.endsWith('.jpg')) {
            try {
              final stat = await entity.stat();
              if (now.difference(stat.modified) > maxAge) {
                await entity.delete();
                AppLogger.d('ImageCompressor: Cleaned up orphaned temp file: ${entity.path}');
              }
            } catch (e) {
              AppLogger.w('ImageCompressor: Failed to delete old file ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      AppLogger.w('ImageCompressor: Cleanup routine failed: $e');
    }
  }
}
