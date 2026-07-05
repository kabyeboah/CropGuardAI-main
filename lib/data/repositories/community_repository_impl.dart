import 'package:uuid/uuid.dart';

import '../../core/error/failures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/result.dart';
import '../../domain/models/community_post.dart';
import '../../domain/repositories/i_community_repository.dart';
import '../local/database_helper.dart';
import '../local/pending_sync_queue.dart';
import '../remote/firestore_service.dart';

class CommunityRepositoryImpl implements ICommunityRepository {
  final FirestoreService _firestoreService;
  final DatabaseHelper _dbHelper;

  CommunityRepositoryImpl(this._firestoreService, this._dbHelper);

  @override
  Stream<List<CommunityPost>> getPostsStream() {
    return _firestoreService.postsStream();
  }

  @override
  Future<Result<void>> addPost(CommunityPost post) async {
    try {
      await _firestoreService.addPost(post);
      return Result.success(null);
    } catch (e) {
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
      await _firestoreService.requestExpertHelp(
        userId: userId,
        detectionId: detectionId,
        message: message,
        diseaseName: diseaseName,
      );
      return Result.success(null);
    } catch (e) {
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
  Future<Result<void>> uploadScan(Map<String, dynamic> scanData) async {
    try {
      await _firestoreService.uploadScan(scanData);
      return Result.success(null);
    } catch (e) {
      return Result.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, dynamic>?>> getUserProfile(String uid) async {
    try {
      final data = await _firestoreService.getUserProfile(uid);
      return Result.success(data);
    } catch (e) {
      return Result.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestoreService.updateUserProfile(uid, data);
      return Result.success(null);
    } catch (e) {
      return Result.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getOutbreakReports() async {
    try {
      final reports = await _firestoreService.getOutbreakReports();
      return Result.success(reports);
    } catch (e) {
      return Result.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> submitOutbreakReport(Map<String, dynamic> data) async {
    try {
      await _firestoreService.submitOutbreakReport(data);
      return Result.success(null);
    } catch (e) {
      // Queue for retry when connectivity is restored.
      await _enqueue(PendingSyncType.outbreakReport, data);
      AppLogger.w('CommunityRepo.submitOutbreakReport offline — queued: $e');
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
      await _firestoreService.verifyOutbreak(
        reportId: reportId,
        userId: userId,
        confirm: confirm,
      );
      return Result.success(null);
    } catch (e) {
      return Result.error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> submitFeedback({
    required String userId,
    required int detectionId,
    required String originalLabel,
    required String correctedLabel,
  }) async {
    try {
      await _firestoreService.submitFeedback(
        userId: userId,
        detectionId: detectionId,
        originalLabel: originalLabel,
        correctedLabel: correctedLabel,
      );
      return Result.success(null);
    } catch (e) {
      await _enqueue(PendingSyncType.feedbackCorrection, {
        'userId': userId,
        'detectionId': detectionId,
        'originalLabel': originalLabel,
        'correctedLabel': correctedLabel,
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
    try {
      await _firestoreService.submitCropNotFound(
        userId: userId,
        suggestedCrop: suggestedCrop,
        observedSymptoms: observedSymptoms,
        imagePath: imagePath,
      );
      return Result.success(null);
    } catch (e) {
      await _enqueue(PendingSyncType.cropNotFound, {
        'userId': userId,
        'suggestedCrop': suggestedCrop,
        'observedSymptoms': observedSymptoms,
        'imagePath': imagePath,
      });
      AppLogger.w('CommunityRepo.submitCropNotFound offline — queued: $e');
      return Result.success(null);
    }
  }

  // ---------------------------------------------------------------------------
  // Offline queue helpers
  // ---------------------------------------------------------------------------

  Future<void> _enqueue(PendingSyncType type, Map<String, dynamic> payload) async {
    final db = await _dbHelper.database;
    await PendingSyncQueue.enqueue(db, type: type, payload: payload);
  }

  /// Drains any operations that were queued while the device was offline.
  /// Call this when [ConnectivityService] reports a transition to online.
  Future<void> drainPendingSync() async {
    final db = await _dbHelper.database;
    await PendingSyncQueue.drain(db, handler: (type, payload) async {
      try {
        switch (type) {
          case PendingSyncType.communityPost:
            // Regenerate a document ID since the original Firestore ID was
            // not persisted in the offline payload.
            final post = CommunityPost.fromMap(
                payload, const Uuid().v4());
            await _firestoreService.addPost(post);
            return true;
          case PendingSyncType.expertRequest:
            await _firestoreService.requestExpertHelp(
              userId: payload['userId'] as String,
              detectionId: payload['detectionId'] as String,
              message: payload['message'] as String,
              diseaseName: payload['diseaseName'] as String,
            );
            return true;
          case PendingSyncType.feedbackCorrection:
            await _firestoreService.submitFeedback(
              userId: payload['userId'] as String,
              detectionId: payload['detectionId'] as int,
              originalLabel: payload['originalLabel'] as String,
              correctedLabel: payload['correctedLabel'] as String,
            );
            return true;
          case PendingSyncType.outbreakReport:
            // outbreakReport entries are filed via submitOutbreakReport, not
            // submitCropNotFound. This case keeps old queued entries working.
            await _firestoreService.submitOutbreakReport(payload);
            return true;
          case PendingSyncType.cropNotFound:
            await _firestoreService.submitCropNotFound(
              userId: payload['userId'] as String,
              suggestedCrop: payload['suggestedCrop'] as String,
              observedSymptoms: payload['observedSymptoms'] as String,
              imagePath: payload['imagePath'] as String,
            );
            return true;
        }
      } catch (_) {
        return false; // Keep in queue; will retry next time.
      }
    });
  }
}
