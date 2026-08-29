import '../../core/utils/result.dart';
import '../../data/local/pending_sync_queue.dart';
import '../models/community_post.dart';

abstract class ICommunityRepository {
  Stream<List<CommunityPost>> getPostsStream();
  Future<Result<void>> addPost(CommunityPost post);
  Future<Result<void>> requestExpertHelp({
    required String userId,
    required String detectionId,
    required String message,
    required String diseaseName,
  });
  Future<Result<void>> uploadScan(Map<String, dynamic> scanData);
  Future<Result<void>> upsertScan(String docId, Map<String, dynamic> scanData);
  Future<Result<Map<String, dynamic>?>> getUserProfile(String uid);
  Future<Result<void>> updateUserProfile(String uid, Map<String, dynamic> data);
  Future<Result<List<Map<String, dynamic>>>> getOutbreakReports();
  Future<Result<void>> submitOutbreakReport(Map<String, dynamic> data);
  Future<Result<void>> verifyOutbreakReport({
    required String reportId,
    required String userId,
    required bool confirm,
  });
  Future<Result<void>> submitFeedback({
    required String userId,
    required int detectionId,
    required String originalLabel,
    required String correctedLabel,
    String? imagePath,
    double? confidence,
    String? modelVersion,
  });

  Future<Result<void>> submitCropNotFound({
    required String userId,
    required String suggestedCrop,
    required String observedSymptoms,
    required String imagePath,
  });

  Future<Result<void>> submitTrainingCandidate(Map<String, dynamic> candidateData);

  Future<Result<void>> reportPost({
    required String postId,
    required String reporterId,
    String? reason,
  });

  Future<List<Map<String, dynamic>>> getPendingSyncItems(PendingSyncType type);
}
