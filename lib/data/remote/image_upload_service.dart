import 'dart:io';

import '../../core/config/app_secrets.dart';
import '../../core/error/failures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/image_compressor.dart';
import 'cloudinary_service.dart';
import 'firebase_storage_service.dart';

/// Unified image uploader providing dual-layer cloud resilience.
///
/// Priority order:
/// 1. Cloudinary Service (if CLOUDINARY_CLOUD_NAME & CLOUDINARY_UPLOAD_PRESET are set)
/// 2. Firebase Storage Service (automatic fallback if Cloudinary is unconfigured or fails)
///
/// Automatically compresses images to ~1080px long edge, ~80% JPEG quality prior to upload.
class ImageUploadService {
  final CloudinaryService _cloudinaryService;
  final FirebaseStorageService _firebaseStorageService;

  ImageUploadService(this._cloudinaryService, this._firebaseStorageService);

  Future<String> uploadImage(String localPath, {String? userId}) async {
    final effectiveUserId = userId ?? 'anonymous';

    String effectivePath = localPath;
    try {
      final file = File(localPath);
      final compressed = await ImageCompressor.compressImage(file);
      effectivePath = compressed.path;
    } catch (e) {
      AppLogger.w('ImageUploadService: Compression pre-step failed, using raw file: $e');
    }

    // 1. Try Cloudinary if configured
    if (AppSecrets.hasCloudinaryConfig) {
      try {
        return await _cloudinaryService.uploadImage(effectivePath);
      } catch (e) {
        AppLogger.w('ImageUploadService: Cloudinary upload failed ($e). Falling back to Firebase Storage.');
      }
    }

    // 2. Fallback to Firebase Storage
    try {
      return await _firebaseStorageService.uploadCommunityImage(
        localPath: effectivePath,
        userId: effectiveUserId,
      );
    } catch (e) {
      AppLogger.e('ImageUploadService: Firebase Storage fallback failed ($e).');
      throw ServerFailure('Image upload failed across Cloudinary and Firebase Storage: $e');
    }
  }
}
