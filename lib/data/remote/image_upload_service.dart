import 'dart:io';

import '../../core/config/app_secrets.dart';
import '../../core/error/failures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/image_compressor.dart';
import '../../core/utils/image_safety_utils.dart';
import 'cloudinary_service.dart';
import 'firebase_storage_service.dart';

/// Unified image uploader providing dual-layer cloud resilience and upload abuse restrictions.
///
/// Priority order:
/// 1. Cloudinary Service (if CLOUDINARY_CLOUD_NAME & CLOUDINARY_UPLOAD_PRESET are set)
/// 2. Firebase Storage Service (automatic fallback if Cloudinary is unconfigured or fails)
///
/// Automatically compresses images to ~1080px long edge, ~80% JPEG quality prior to upload.
class ImageUploadService {
  static const int maxUploadSizeBytes = 10 * 1024 * 1024; // 10MB raw cap
  static const Set<String> allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final CloudinaryService _cloudinaryService;
  final FirebaseStorageService _firebaseStorageService;

  ImageUploadService(this._cloudinaryService, this._firebaseStorageService);

  Future<String> uploadImage(String localPath, {String? userId}) async {
    final effectiveUserId = userId ?? 'anonymous';
    final file = File(localPath);

    File? tempCompressedFile;
    String effectivePath = localPath;

    if (await file.exists()) {
      final extension = localPath.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(extension)) {
        throw ServerFailure(
            'Invalid image format (.$extension). Allowed formats: JPG, PNG, WEBP.');
      }

      final fileSize = await file.length();
      if (fileSize > maxUploadSizeBytes) {
        throw const ServerFailure(
            'Image file size exceeds maximum limit of 10MB.');
      }

      try {
        final decoded = await ImageSafetyUtils.safeDecodeFile(file);
        if (decoded == null) {
          throw const ImageCorruptException(
              'Image data could not be decoded safely.');
        }

        final compressed = await ImageCompressor.compressImage(file);
        if (compressed.path != file.path) {
          tempCompressedFile = compressed;
        }
        effectivePath = compressed.path;
      } catch (e) {
        if (e is ImageSafetyException) {
          throw ServerFailure(e.message);
        }
        AppLogger.w('ImageUploadService: Compression pre-step warning: $e');
      }
    }

    try {
      // 1. Try Cloudinary if configured
      if (AppSecrets.hasCloudinaryConfig) {
        try {
          return await _cloudinaryService.uploadImage(effectivePath);
        } catch (e) {
          AppLogger.w(
              'ImageUploadService: Cloudinary upload failed ($e). Falling back to Firebase Storage.');
        }
      }

      // 2. Fallback to Firebase Storage
      try {
        return await _firebaseStorageService.uploadCommunityImage(
          localPath: effectivePath,
          userId: effectiveUserId,
        );
      } catch (e) {
        AppLogger.e(
            'ImageUploadService: Firebase Storage fallback failed ($e).');
        throw ServerFailure(
            'Image upload failed across Cloudinary and Firebase Storage: $e');
      }
    } finally {
      if (tempCompressedFile != null) {
        try {
          if (await tempCompressedFile.exists()) {
            await tempCompressedFile.delete();
            AppLogger.d(
                'ImageUploadService: Cleaned up temporary compressed file: ${tempCompressedFile.path}');
          }
        } catch (e) {
          AppLogger.w(
              'ImageUploadService: Failed to delete temp compressed file: $e');
        }
      }
    }
  }
}
