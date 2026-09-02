import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/failures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/retry_utils.dart';
import '../../domain/models/community_post.dart';

/// Supabase Database service — replaces FirestoreService with PostgreSQL tables
class SupabaseDatabaseService {
  final SupabaseClient _client;

  SupabaseDatabaseService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  bool _isTransientError(Object error) {
    if (error is PostgrestException) {
      final code = error.code;
      if (code == '500' || code == '503' || code == '504' || code == '429') {
        return true;
      }
    }
    return error is TimeoutException || error is SocketException;
  }

  // ─── Community Posts ──────────────────────────────────────────────────
  Stream<List<CommunityPost>> postsStream() {
    return _client
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows
            .map((row) => CommunityPost(
                  id: row['id']?.toString() ?? '',
                  userId: row['user_id']?.toString() ?? '',
                  author: row['author_name']?.toString() ?? 'Farmer',
                  tag: row['crop_type']?.toString() ?? 'General',
                  body: row['content']?.toString() ?? '',
                  imageUri: row['image_url']?.toString(),
                  timestamp: DateTime.tryParse(row['created_at']?.toString() ?? '')
                          ?.millisecondsSinceEpoch ??
                      DateTime.now().millisecondsSinceEpoch,
                ))
            .toList())
        .handleError((error) {
      AppLogger.w('Supabase postsStream error: $error');
      return <CommunityPost>[];
    });
  }

  Future<void> addPost(CommunityPost post) async {
    try {
      await RetryUtils.retry(
        () => _client.from('posts').insert({
          'user_id': post.userId,
          'author_name': post.author,
          'crop_type': post.tag,
          'title': post.tag,
          'content': post.body,
          'image_url': post.imageUri,
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to add post: $e');
    }
  }

  // ─── Expert Consultation ──────────────────────────────────────────────
  Future<void> requestExpertHelp({
    required String userId,
    required String detectionId,
    required String message,
    required String diseaseName,
  }) async {
    try {
      await RetryUtils.retry(
        () => _client.from('expert_requests').insert({
          'user_id': userId,
          'detection_id': detectionId,
          'message': message,
          'disease_name': diseaseName,
          'status': 'pending',
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to request expert help: $e');
    }
  }

  // ─── Scan Sync ────────────────────────────────────────────────────────
  Future<void> upsertScan(String docId, Map<String, dynamic> scanData) async {
    try {
      final rawImageUrl = scanData['imageUrl'] ?? scanData['image_url'];
      final rawImagePath = scanData['imagePath'] ?? scanData['image_path'];
      final validHttpUrl = (rawImageUrl is String && rawImageUrl.startsWith('http'))
          ? rawImageUrl
          : ((rawImagePath is String && rawImagePath.startsWith('http'))
              ? rawImagePath
              : null);

      await RetryUtils.retry(
        () => _client.from('scans').upsert({
          'id': docId,
          'user_id': scanData['userId'] ?? scanData['user_id'],
          'disease_name': scanData['displayName'] ??
              scanData['diseaseLabel'] ??
              scanData['diseaseName'] ??
              scanData['disease'],
          'crop_type': scanData['cropType'] ?? scanData['crop_type'] ?? scanData['crop'],
          'confidence': scanData['confidence'],
          'image_url': validHttpUrl,
          'data': scanData,
          'created_at': scanData['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                      int.tryParse(scanData['timestamp'].toString()) ??
                          DateTime.now().millisecondsSinceEpoch)
                  .toIso8601String()
              : DateTime.now().toIso8601String(),
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to upsert scan: $e');
    }
  }

  Future<void> uploadScan(Map<String, dynamic> scanData) async {
    try {
      final rawImageUrl = scanData['imageUrl'] ?? scanData['image_url'];
      final rawImagePath = scanData['imagePath'] ?? scanData['image_path'];
      final validHttpUrl = (rawImageUrl is String && rawImageUrl.startsWith('http'))
          ? rawImageUrl
          : ((rawImagePath is String && rawImagePath.startsWith('http'))
              ? rawImagePath
              : null);

      await RetryUtils.retry(
        () => _client.from('scans').insert({
          'user_id': scanData['userId'] ?? scanData['user_id'],
          'disease_name': scanData['displayName'] ??
              scanData['diseaseLabel'] ??
              scanData['diseaseName'] ??
              scanData['disease'],
          'crop_type': scanData['cropType'] ?? scanData['crop_type'] ?? scanData['crop'],
          'confidence': scanData['confidence'],
          'image_url': validHttpUrl,
          'data': scanData,
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to upload scan: $e');
    }
  }

  // ─── User Profile ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final response = await RetryUtils.retry(
        () => _client.from('profiles').select().eq('id', uid).maybeSingle(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
      return response;
    } catch (e) {
      AppLogger.w('Supabase getUserProfile error: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await RetryUtils.retry(
        () => _client.from('profiles').upsert({
          'id': uid,
          ...data,
          'updated_at': DateTime.now().toIso8601String(),
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to update user profile: $e');
    }
  }

  // ─── Outbreak Map ─────────────────────────────────────────────────────
  Future<void> submitOutbreakReport(Map<String, dynamic> data) async {
    try {
      await RetryUtils.retry(
        () => _client.from('outbreaks').insert({
          'user_id': data['userId'],
          'disease_name': data['diseaseName'] ?? 'Unknown',
          'crop_type': data['cropType'] ?? 'Unknown',
          'confidence': data['confidence'] ?? 0.0,
          'latitude': data['latitude'] ?? 0.0,
          'longitude': data['longitude'] ?? 0.0,
          'district': data['district'],
          'region': data['region'],
          'verified_by': data['userId'] != null ? [data['userId']] : [],
          'refuted_by': [],
        }),
        maxAttempts: 2,
        timeout: const Duration(seconds: 5),
        retryIf: _isTransientError,
      );
    } catch (e) {
      AppLogger.w('Supabase submitOutbreakReport warning: $e');
    }
  }

  Future<void> verifyOutbreak({
    required String reportId,
    required String userId,
    required bool confirm,
  }) async {
    try {
      final report = await _client.from('outbreaks').select().eq('id', reportId).maybeSingle();
      if (report == null) throw const ServerFailure('Outbreak report not found');

      final verifiedBy = List<String>.from(report['verified_by'] ?? []);
      final refutedBy = List<String>.from(report['refuted_by'] ?? []);

      if (confirm) {
        if (!verifiedBy.contains(userId)) verifiedBy.add(userId);
        refutedBy.remove(userId);
      } else {
        if (!refutedBy.contains(userId)) refutedBy.add(userId);
        verifiedBy.remove(userId);
      }

      await _client.from('outbreaks').update({
        'verified_by': verifiedBy,
        'refuted_by': refutedBy,
      }).eq('id', reportId);
    } catch (e) {
      throw ServerFailure('Failed to verify outbreak: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getOutbreakReports() async {
    try {
      final rows = await RetryUtils.retry(
        () => _client.from('outbreaks').select().order('created_at', ascending: false).limit(100),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
      return List<Map<String, dynamic>>.from(rows.map((r) => {
        'id': r['id']?.toString(),
        'userId': r['user_id'],
        'diseaseName': r['disease_name'],
        'cropType': r['crop_type'],
        'confidence': r['confidence'],
        'latitude': r['latitude'],
        'longitude': r['longitude'],
        'district': r['district'],
        'region': r['region'],
        'verifiedBy': r['verified_by'] ?? [],
        'refutedBy': r['refuted_by'] ?? [],
        'timestamp': DateTime.tryParse(r['created_at']?.toString() ?? '')?.millisecondsSinceEpoch,
        ...r,
      }));
    } catch (e) {
      AppLogger.w('Supabase getOutbreakReports error: $e');
      return [];
    }
  }

  Future<Map<String, int>> getReporterTrustStats(String userId) async {
    if (userId.isEmpty) {
      return {
        'totalSubmitted': 0,
        'verifiedReports': 0,
        'verificationsGiven': 0,
        'refutedReports': 0,
      };
    }
    try {
      final myReports = await _client.from('outbreaks').select().eq('user_id', userId);
      int totalSubmitted = myReports.length;
      int verifiedReports = 0;
      int refutedReports = 0;

      for (final doc in myReports) {
        final verifiedBy = (doc['verified_by'] as List?) ?? [];
        final refutedBy = (doc['refuted_by'] as List?) ?? [];
        if (verifiedBy.length >= 2 ||
            (verifiedBy.length > refutedBy.length && verifiedBy.isNotEmpty)) {
          verifiedReports++;
        }
        if (refutedBy.length > verifiedBy.length) {
          refutedReports++;
        }
      }

      final allReports = await _client.from('outbreaks').select('verified_by');
      int verificationsGiven = 0;
      for (final r in allReports) {
        final v = (r['verified_by'] as List?) ?? [];
        if (v.contains(userId)) verificationsGiven++;
      }

      return {
        'totalSubmitted': totalSubmitted,
        'verifiedReports': verifiedReports,
        'verificationsGiven': verificationsGiven,
        'refutedReports': refutedReports,
      };
    } catch (e) {
      AppLogger.w('Supabase: getReporterTrustStats failed: $e');
      return {
        'totalSubmitted': 0,
        'verifiedReports': 0,
        'verificationsGiven': 0,
        'refutedReports': 0,
      };
    }
  }

  // ─── Treatment Tracking ───────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> treatmentsStream(
    String userId, {
    int limit = 100,
  }) {
    return _client
        .from('treatments')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .limit(limit)
        .map((rows) => rows.map((row) => Map<String, dynamic>.from(row)).toList())
        .handleError((error) {
      AppLogger.w('Supabase treatmentsStream error: $error');
      return <Map<String, dynamic>>[];
    });
  }

  Future<void> addTreatment(Map<String, dynamic> data) async {
    try {
      await RetryUtils.retry(
        () => _client.from('treatments').insert(data),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to add treatment: $e');
    }
  }

  Future<void> updateTreatment(String id, Map<String, dynamic> data) async {
    try {
      await RetryUtils.retry(
        () => _client.from('treatments').update(data).eq('id', id),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to update treatment: $e');
    }
  }

  Future<void> deleteTreatment(String id) async {
    try {
      await RetryUtils.retry(
        () => _client.from('treatments').delete().eq('id', id),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to delete treatment: $e');
    }
  }

  // ─── Feedback & Submissions ───────────────────────────────────────────
  Future<void> submitFeedback({
    required String userId,
    required int detectionId,
    required String originalLabel,
    required String correctedLabel,
    String? imagePath,
    double? confidence,
    String? modelVersion,
  }) async {
    try {
      await RetryUtils.retry(
        () => _client.from('feedback').insert({
          'user_id': userId,
          'detection_id': detectionId,
          'original_label': originalLabel,
          'corrected_label': correctedLabel,
          'image_path': imagePath,
          'confidence': confidence,
          'model_version': modelVersion,
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to submit feedback: $e');
    }
  }

  Future<void> submitCropNotFound({
    required String userId,
    required String suggestedCrop,
    required String observedSymptoms,
    required String imagePath,
  }) async {
    try {
      await RetryUtils.retry(
        () => _client.from('missing_crops').insert({
          'user_id': userId,
          'suggested_crop': suggestedCrop,
          'observed_symptoms': observedSymptoms,
          'image_path': imagePath,
          'status': 'review_pending',
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to submit missing crop report: $e');
    }
  }

  Future<void> submitTrainingCandidate(
      Map<String, dynamic> candidateData) async {
    try {
      await RetryUtils.retry(
        () => _client.from('training_candidates').insert(candidateData),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to submit training candidate: $e');
    }
  }

  Future<void> reportPost({
    required String postId,
    required String reporterId,
    String? reason,
  }) async {
    try {
      await RetryUtils.retry(
        () => _client.from('reported_posts').insert({
          'post_id': postId,
          'reporter_id': reporterId,
          'user_id': reporterId,
          'reason': reason ?? 'inappropriate_content',
          'status': 'pending_review',
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to report post: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserExpertRequests(
      String userId) async {
    if (userId.isEmpty) return [];
    try {
      final rows = await RetryUtils.retry(
        () => _client
            .from('expert_requests')
            .select()
            .eq('user_id', userId),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
      return List<Map<String, dynamic>>.from(rows.map((r) => {
        'id': r['id']?.toString(),
        'userId': r['user_id'],
        'detectionId': r['detection_id'],
        'message': r['message'],
        'diseaseName': r['disease_name'],
        'status': r['status'],
        'timestamp': DateTime.tryParse(r['created_at']?.toString() ?? '')?.millisecondsSinceEpoch,
        'type': 'expert_request',
      }));
    } catch (e) {
      AppLogger.w('Supabase: getUserExpertRequests error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserMissingCrops(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final rows = await RetryUtils.retry(
        () => _client
            .from('missing_crops')
            .select()
            .eq('user_id', userId),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isTransientError,
      );
      return List<Map<String, dynamic>>.from(rows.map((r) => {
        'id': r['id']?.toString(),
        'userId': r['user_id'],
        'suggestedCrop': r['suggested_crop'],
        'observedSymptoms': r['observed_symptoms'],
        'imagePath': r['image_path'],
        'status': r['status'],
        'timestamp': DateTime.tryParse(r['created_at']?.toString() ?? '')?.millisecondsSinceEpoch,
        'type': 'missing_crop',
      }));
    } catch (e) {
      AppLogger.w('Supabase: getUserMissingCrops error: $e');
      return [];
    }
  }

  // ─── Delete Account / Cascading Purge ──────────────────────────────────
  Future<void> deleteUserData(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _client.from('profiles').delete().eq('id', uid);
      await _client.from('posts').delete().eq('user_id', uid);
      await _client.from('treatments').delete().eq('user_id', uid);
      await _client.from('scans').delete().eq('user_id', uid);
      await _client.from('feedback').delete().eq('user_id', uid);
      await _client.from('missing_crops').delete().eq('user_id', uid);
      await _client.from('expert_requests').delete().eq('user_id', uid);
    } catch (e) {
      AppLogger.w('Supabase deleteUserData error: $e');
    }
  }
}
