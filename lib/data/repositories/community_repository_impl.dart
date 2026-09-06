import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/failures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/result.dart';
import '../../domain/models/community_post.dart';
import '../../domain/repositories/i_community_repository.dart';
import '../local/database_helper.dart';
import '../local/pending_sync_queue.dart';
import '../remote/supabase_database_service.dart';
import '../remote/image_upload_service.dart';

class CommunityRepositoryImpl implements ICommunityRepository {
  final SupabaseDatabaseService _databaseService;
  final DatabaseHelper _dbHelper;
  final ImageUploadService _imageUploadService;

  CommunityRepositoryImpl(
      this._databaseService, this._dbHelper, this._imageUploadService);

  @override
  Stream<List<CommunityPost>> getPostsStream() {
    return _databaseService.postsStream();
  }

  @override
  Future<Result<void>> addPost(CommunityPost post) async {
    try {
      if (post.imageUri != null && !post.imageUri!.startsWith('http')) {
        throw Exception('Image upload pending');
      }
      await _databaseService.addPost(post);
      return Result.success(null);
    } catch (e) {
      if (!_isTransientError(e)) {
        AppLogger.e(
            'CommunityRepo.addPost permanent failure — not queuing: $e');
        return Result.error(ServerFailure(e.toString()));
      }
      // Queue for retry when connectivity is restored.
      await _enqueue(PendingSyncType.communityPost, post.toMap());
      AppLogger.w('CommunityRepo.addPost offline — queued: $e');
      return Result.success(null); // Optimistic: the user sees "posted".
    }
  }

  @override
  Future<Result<void>> requestExpertHelp({
    required String userId,
    required String detectionId,
    required String message,
    required String diseaseName,
  }) async {
    try {
      await _databaseService.requestExpertHelp(
        userId: userId,
        detectionId: detectionId,
        message: message,
        diseaseName: diseaseName,
      );
      return Result.success(null);
    } catch (e) {
      if (!_isTransientError(e)) {
        AppLogger.e(
            'CommunityRepo.requestExpertHelp permanent failure — not queuing: $e');
        return Result.error(ServerFailure(e.toString()));
      }
      await _enqueue(PendingSyncType.expertRequest, {
        'userId': userId,
        'detectionId': detectionId,
        'message': message,
        'diseaseName': diseaseName,
      });
      AppLogger.w('CommunityRepo.requestExpertHelp offline — queued: $e');
      return Result.success(null);
    }
  }

  @override
  Future<Result<void>> upsertScan(
      String docId, Map<String, dynamic> scanData) async {
    try {
      await _databaseService
          .upsertScan(docId, scanData)
          .timeout(const Duration(seconds: 4));
      final intId = int.tryParse(docId);
      if (intId != null) {
        await _dbHelper.markDetectionSynced(intId);
      }
      return Result.success(null);
    } catch (e) {
      final payload = Map<String, dynamic>.from(scanData);
      payload['id'] = docId;
      await _enqueue(PendingSyncType.scanUpload, payload);
      AppLogger.w('CommunityRepo.upsertScan offline/timeout — queued: $e');
      return Result.success(null);
    }
  }

  @override
  Future<Result<void>> uploadScan(Map<String, dynamic> scanData) async {
    final docId = scanData['id']?.toString();
    if (docId != null && docId.isNotEmpty && docId != '0') {
      return upsertScan(docId, scanData);
    }
    try {
      await _databaseService
          .uploadScan(scanData)
          .timeout(const Duration(seconds: 4));
      return Result.success(null);
    } catch (e) {
      await _enqueue(PendingSyncType.scanUpload, scanData);
      AppLogger.w('CommunityRepo.uploadScan offline/timeout — queued: $e');
      return Result.success(null);
    }
  }

  @override
  Future<Result<Map<String, dynamic>?>> getUserProfile(String uid) async {
    try {
      final data = await _databaseService.getUserProfile(uid);
      return Result.success(data);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updateUserProfile(
      String uid, Map<String, dynamic> data) async {
    try {
      await _databaseService.updateUserProfile(uid, data);
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getOutbreakReports() async {
    List<Map<String, dynamic>> cloudReports = [];
    try {
      cloudReports = await _databaseService.getOutbreakReports();
    } catch (e) {
      AppLogger.w('CommunityRepo.getOutbreakReports cloud fetch failed: $e');
    }

    try {
      final db = await _dbHelper.database;
      final pendingRows = await PendingSyncQueue.getPendingItems(
        db,
        type: PendingSyncType.outbreakReport,
      );
      final pendingReports = pendingRows.map((r) {
        final payloadJson = r['payload'] as String? ?? '{}';
        final map = Map<String, dynamic>.from(jsonDecode(payloadJson) as Map);
        map['id'] = map['id'] ?? 'pending_${r['id']}';
        map['isPending'] = true;
        return map;
      }).toList();

      if (pendingReports.isNotEmpty) {
        return Result.success([...pendingReports, ...cloudReports]);
      }
    } catch (e) {
      AppLogger.w(
          'CommunityRepo.getOutbreakReports pending queue fetch failed: $e');
    }

    return Result.success(cloudReports);
  }

  @override
  Future<Result<void>> submitOutbreakReport(Map<String, dynamic> data) async {
    final userId = data['userId'] as String?;
    if (userId == null || userId.trim().isEmpty) {
      return Result.error(const AuthFailure(
          'You must be signed in to submit an outbreak report.'));
    }
    try {
      await _databaseService
          .submitOutbreakReport(data)
          .timeout(const Duration(seconds: 4));
      return Result.success(null);
    } catch (e) {
      if (!_isTransientError(e)) {
        AppLogger.e(
            'CommunityRepo.submitOutbreakReport permanent failure — not queuing: $e');
        return Result.error(ServerFailure(e.toString()));
      }
      await _enqueue(PendingSyncType.outbreakReport, data);
      AppLogger.w(
          'CommunityRepo.submitOutbreakReport timeout/offline — queued: $e');
      return Result.success(null); // Optimistic: the user sees "reported".
    }
  }

  @override
  Future<Result<void>> verifyOutbreakReport({
    required String reportId,
    required String userId,
    required bool confirm,
  }) async {
    try {
      await _databaseService.verifyOutbreak(
        reportId: reportId,
        userId: userId,
        confirm: confirm,
      );
      return Result.success(null);
    } catch (e) {
      if (e is Failure) return Result.error(e);
      return Result.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> submitFeedback({
    required String userId,
    required int detectionId,
    required String originalLabel,
    required String correctedLabel,
    String? imagePath,
    double? confidence,
    String? modelVersion,
  }) async {
    String? remoteUrl = imagePath;
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('http')) {
      try {
        remoteUrl =
            await _imageUploadService.uploadImage(imagePath, userId: userId);
      } catch (e) {
        await _enqueue(PendingSyncType.feedbackCorrection, {
          'userId': userId,
          'detectionId': detectionId,
          'originalLabel': originalLabel,
          'correctedLabel': correctedLabel,
          'imagePath': imagePath,
          'confidence': confidence,
          'modelVersion': modelVersion,
        });
        AppLogger.w(
            'CommunityRepo.submitFeedback image upload failed — queued: $e');
        return Result.success(null);
      }
    }

    try {
      await _databaseService.submitFeedback(
        userId: userId,
        detectionId: detectionId,
        originalLabel: originalLabel,
        correctedLabel: correctedLabel,
        imagePath: remoteUrl,
        confidence: confidence,
        modelVersion: modelVersion,
      );
      return Result.success(null);
    } catch (e) {
      if (!_isTransientError(e)) {
        AppLogger.e(
            'CommunityRepo.submitFeedback permanent failure — not queuing: $e');
        return Result.error(ServerFailure(e.toString()));
      }
      await _enqueue(PendingSyncType.feedbackCorrection, {
        'userId': userId,
        'detectionId': detectionId,
        'originalLabel': originalLabel,
        'correctedLabel': correctedLabel,
        'imagePath': remoteUrl,
        'confidence': confidence,
        'modelVersion': modelVersion,
      });
      AppLogger.w('CommunityRepo.submitFeedback offline — queued: $e');
      return Result.success(null);
    }
  }

  @override
  Future<Result<void>> submitCropNotFound({
    required String userId,
    required String suggestedCrop,
    required String observedSymptoms,
    required String imagePath,
  }) async {
    String remoteUrl = imagePath;
    if (imagePath.isNotEmpty && !imagePath.startsWith('http')) {
      try {
        remoteUrl =
            await _imageUploadService.uploadImage(imagePath, userId: userId);
      } catch (e) {
        await _enqueue(PendingSyncType.cropNotFound, {
          'userId': userId,
          'suggestedCrop': suggestedCrop,
          'observedSymptoms': observedSymptoms,
          'imagePath': imagePath,
        });
        AppLogger.w('submitCropNotFound image upload failed — queued: $e');
        return Result.success(null);
      }
    }

    try {
      await _databaseService.submitCropNotFound(
        userId: userId,
        suggestedCrop: suggestedCrop,
        observedSymptoms: observedSymptoms,
        imagePath: remoteUrl,
      );
      return Result.success(null);
    } catch (e) {
      if (!_isTransientError(e)) {
        AppLogger.e(
            'CommunityRepo.submitCropNotFound permanent failure — not queuing: $e');
        return Result.error(ServerFailure(e.toString()));
      }
      await _enqueue(PendingSyncType.cropNotFound, {
        'userId': userId,
        'suggestedCrop': suggestedCrop,
        'observedSymptoms': observedSymptoms,
        'imagePath': remoteUrl,
      });
      AppLogger.w('CommunityRepo.submitCropNotFound offline — queued: $e');
      return Result.success(null);
    }
  }

  @override
  Future<Result<void>> submitTrainingCandidate(
      Map<String, dynamic> candidateData) async {
    final imagePath = candidateData['imagePath'] as String? ?? '';
    final userId = candidateData['userId'] as String? ?? '';
    var cloudUrl = imagePath;
    if (imagePath.isNotEmpty && !imagePath.startsWith('http')) {
      try {
        cloudUrl =
            await _imageUploadService.uploadImage(imagePath, userId: userId);
      } catch (e) {
        await _enqueue(PendingSyncType.trainingCandidate, candidateData);
        AppLogger.w('submitTrainingCandidate image upload failed — queued: $e');
        return Result.success(null);
      }
    }

    final payload = Map<String, dynamic>.from(candidateData)
      ..['imagePath'] = cloudUrl;

    try {
      await _databaseService.submitTrainingCandidate(payload);
      return Result.success(null);
    } catch (e) {
      await _enqueue(PendingSyncType.trainingCandidate, payload);
      AppLogger.w('CommunityRepo.submitTrainingCandidate offline — queued: $e');
      return Result.success(null);
    }
  }

  @override
  Future<Result<void>> reportPost({
    required String postId,
    required String reporterId,
    String? reason,
  }) async {
    if (reporterId.isEmpty) {
      return Result.error(
          const AuthFailure('You must be signed in to report a post.'));
    }
    try {
      await _databaseService.reportPost(
        postId: postId,
        reporterId: reporterId,
        reason: reason,
      );
      return Result.success(null);
    } catch (e) {
      if (!_isTransientError(e)) {
        AppLogger.e(
            'CommunityRepo.reportPost permanent failure — not queuing: $e');
        return Result.error(ServerFailure(e.toString()));
      }
      await _enqueue(PendingSyncType.reportedPost, {
        'postId': postId,
        'reporterId': reporterId,
        'reason': reason ?? 'inappropriate_content',
      });
      AppLogger.w('CommunityRepo.reportPost offline — queued: $e');
      return Result.success(null);
    }
  }

  // ---------------------------------------------------------------------------
  // Offline queue helpers
  // ---------------------------------------------------------------------------

  static bool _isTransientError(Object e) {
    if (e is AuthFailure) return false;
    if (e is PostgrestException) {
      final code = e.code;
      if (code == '42501' || code == '23505' || code == '23503') {
        // Permission denied / unique violation / foreign key violation -> permanent
        return false;
      }
    }
    return true;
  }

  Future<void> _enqueue(
      PendingSyncType type, Map<String, dynamic> payload) async {
    final db = await _dbHelper.database;
    await PendingSyncQueue.enqueue(db, type: type, payload: payload);
  }

  Future<void> drainPendingSync() async {
    final db = await _dbHelper.database;
    await PendingSyncQueue.drain(db, handler: (rowId, type, payload) async {
      try {
        switch (type) {
          case PendingSyncType.communityPost:
            final imagePath = payload['imageUri'] as String?;
            String? remoteUrl = imagePath;
            if (imagePath != null && !imagePath.startsWith('http')) {
              try {
                remoteUrl = await _imageUploadService.uploadImage(
                  imagePath,
                  userId: payload['userId'] as String?,
                );
                final updatedPayload = Map<String, dynamic>.from(payload)
                  ..['imageUri'] = remoteUrl;
                await PendingSyncQueue.updatePayload(db, rowId, updatedPayload);
              } catch (e) {
                AppLogger.e('CommunityRepo drain: image upload failed: $e');
                return false;
              }
            }

            final post = CommunityPost.fromMap(
              {...payload, if (remoteUrl != null) 'imageUri': remoteUrl},
              const Uuid().v4(),
            );
            await _databaseService.addPost(post);
            return true;

          case PendingSyncType.expertRequest:
            await _databaseService.requestExpertHelp(
              userId: payload['userId'] as String,
              detectionId: payload['detectionId'] as String,
              message: payload['message'] as String,
              diseaseName: payload['diseaseName'] as String,
            );
            return true;

          case PendingSyncType.feedbackCorrection:
            final localImg = payload['imagePath'] as String?;
            var cloudUrl = localImg;
            if (localImg != null &&
                localImg.isNotEmpty &&
                !localImg.startsWith('http')) {
              try {
                cloudUrl = await _imageUploadService.uploadImage(localImg,
                    userId: payload['userId'] as String?);
              } catch (e) {
                AppLogger.w(
                    'CommunityRepo drain: feedback image upload failed: $e');
                return false;
              }
            }
            if (cloudUrl != null &&
                cloudUrl.isNotEmpty &&
                !cloudUrl.startsWith('http')) {
              return false;
            }
            await _databaseService.submitFeedback(
              userId: payload['userId'] as String,
              detectionId: payload['detectionId'] as int,
              originalLabel: payload['originalLabel'] as String,
              correctedLabel: payload['correctedLabel'] as String,
              imagePath: cloudUrl,
              confidence: (payload['confidence'] as num?)?.toDouble(),
              modelVersion: payload['modelVersion'] as String?,
            );
            return true;

          case PendingSyncType.outbreakReport:
            final replayPayload = Map<String, dynamic>.from(payload);
            replayPayload['syncedAt'] = DateTime.now().toIso8601String();
            await _databaseService.submitOutbreakReport(replayPayload);
            return true;

          case PendingSyncType.cropNotFound:
            final localImg = payload['imagePath'] as String? ?? '';
            var cloudUrl = localImg;
            if (localImg.isNotEmpty && !localImg.startsWith('http')) {
              try {
                cloudUrl = await _imageUploadService.uploadImage(localImg,
                    userId: payload['userId'] as String?);
              } catch (e) {
                AppLogger.w(
                    'CommunityRepo drain: cropNotFound image upload failed: $e');
                return false;
              }
            }
            if (cloudUrl.isNotEmpty && !cloudUrl.startsWith('http')) {
              return false;
            }
            await _databaseService.submitCropNotFound(
              userId: payload['userId'] as String,
              suggestedCrop: payload['suggestedCrop'] as String,
              observedSymptoms: payload['observedSymptoms'] as String,
              imagePath: cloudUrl,
            );
            return true;

          case PendingSyncType.scanUpload:
            final docId =
                payload['id']?.toString() ?? payload['timestamp']?.toString();
            if (docId != null && docId.isNotEmpty) {
              await _databaseService.upsertScan(docId, payload);
              final intId = int.tryParse(docId);
              if (intId != null) {
                await _dbHelper.markDetectionSynced(intId);
              }
            } else {
              await _databaseService.uploadScan(payload);
            }
            return true;

          case PendingSyncType.treatmentAdd:
            await _databaseService.addTreatment(payload);
            return true;

          case PendingSyncType.treatmentUpdate:
            final treatmentId = payload['id'] as String;
            final updateData =
                Map<String, dynamic>.from(payload['data'] as Map);
            await _databaseService.updateTreatment(treatmentId, updateData);
            return true;

          case PendingSyncType.treatmentDelete:
            await _databaseService.deleteTreatment(payload['id'] as String);
            return true;

          case PendingSyncType.trainingCandidate:
            final localImg = payload['imagePath'] as String? ?? '';
            var cloudUrl = localImg;
            if (localImg.isNotEmpty && !localImg.startsWith('http')) {
              try {
                cloudUrl = await _imageUploadService.uploadImage(localImg,
                    userId: payload['userId'] as String?);
              } catch (e) {
                AppLogger.w(
                    'CommunityRepo drain: trainingCandidate image upload failed: $e');
                return false;
              }
            }
            if (cloudUrl.isNotEmpty && !cloudUrl.startsWith('http')) {
              return false;
            }
            final finalPayload = Map<String, dynamic>.from(payload)
              ..['imagePath'] = cloudUrl;
            await _databaseService.submitTrainingCandidate(finalPayload);
            return true;

          case PendingSyncType.reportedPost:
            await _databaseService.reportPost(
              postId: payload['postId'] as String,
              reporterId: payload['reporterId'] as String,
              reason: payload['reason'] as String?,
            );
            return true;
        }
      } catch (_) {
        return false;
      }
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncItems(
      PendingSyncType type) async {
    final db = await _dbHelper.database;
    return PendingSyncQueue.getPendingItems(db, type: type);
  }
}
