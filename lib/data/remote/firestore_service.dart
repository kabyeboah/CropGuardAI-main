import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/error/failures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/retry_utils.dart';
import '../../domain/models/community_post.dart';

/// Firestore service — replaces Firebase-backed repository implementations
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isFirestoreTransientError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
        case 'deadline-exceeded':
        case 'internal':
          return true;
        default:
          return false;
      }
    }
    return error is TimeoutException || error is SocketException;
  }

  // ─── Community Posts ──────────────────────────────────────────────────
  Stream<List<CommunityPost>> postsStream() {
    return _db
        .collection('community_posts')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommunityPost.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((error) {
          throw ServerFailure('Failed to stream community posts: $error');
        });
  }

  Future<void> addPost(CommunityPost post) async {
    try {
      await RetryUtils.retry(
        () => _db.collection('community_posts').add(post.toMap()),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
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
        () => _db.collection('expert_requests').add({
          'userId': userId,
          'detectionId': detectionId,
          'message': message,
          'diseaseName': diseaseName,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to request expert help: $e');
    }
  }

  // ─── Scan Sync ────────────────────────────────────────────────────────

  /// Writes scan data using [docId] as the Firestore document ID.
  /// Using set() instead of add() makes every sync run idempotent: re-running
  /// the background task overwrites the same document rather than duplicating it.
  Future<void> upsertScan(String docId, Map<String, dynamic> scanData) async {
    try {
      await RetryUtils.retry(
        () => _db.collection('scans').doc(docId).set(scanData),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to upsert scan: $e');
    }
  }

  /// Kept for call-sites outside the background sync path.
  Future<void> uploadScan(Map<String, dynamic> scanData) async {
    try {
      await RetryUtils.retry(
        () => _db.collection('scans').add(scanData),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to upload scan: $e');
    }
  }

  // ─── User profile ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await RetryUtils.retry(
        () => _db.collection('users').doc(uid).get(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
      return doc.data();
    } catch (e) {
      throw ServerFailure('Failed to get user profile: $e');
    }
  }

  Future<void> updateUserProfile(
      String uid, Map<String, dynamic> data) async {
    try {
      await RetryUtils.retry(
        () => _db
            .collection('users')
            .doc(uid)
            .set(data, SetOptions(merge: true)),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to update user profile: $e');
    }
  }

  // ─── Outbreak Map ─────────────────────────────────────────────────────

  /// Submits a crowd-sourced outbreak report. [data] must include a [userId]
  /// field matching the caller's UID so Firestore security rules can validate it.
  Future<void> submitOutbreakReport(Map<String, dynamic> data) async {
    try {
      final reportData = {
        ...data,
        'verifiedBy': data['userId'] != null ? [data['userId']] : [],
        'refutedBy': [],
      };
      await RetryUtils.retry(
        () => _db.collection('outbreak_reports').add(reportData),
        maxAttempts: 2,
        timeout: const Duration(seconds: 4),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to submit outbreak report: $e');
    }
  }


  Future<void> verifyOutbreak({
    required String reportId,
    required String userId,
    required bool confirm,
  }) async {
    try {
      final docRef = _db.collection('outbreak_reports').doc(reportId);
      await RetryUtils.retry(() async {
        if (confirm) {
          await docRef.update({
            'verifiedBy': FieldValue.arrayUnion([userId]),
            'refutedBy': FieldValue.arrayRemove([userId]),
          });
        } else {
          await docRef.update({
            'verifiedBy': FieldValue.arrayRemove([userId]),
            'refutedBy': FieldValue.arrayUnion([userId]),
          });
        }
      },
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to verify outbreak: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getOutbreakReports() async {
    try {
      final snap = await RetryUtils.retry(
        () => _db
            .collection('outbreak_reports')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .get(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
      return snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((data) =>
              data['isSeed'] != true &&
              data['source'] != 'seed' &&
              !(data['id']?.toString().startsWith('seed_') ?? false))
          .toList();
    } catch (e) {
      throw ServerFailure('Failed to get outbreak reports: $e');
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
      final myReportsSnap = await RetryUtils.retry(
        () => _db
            .collection('outbreak_reports')
            .where('userId', isEqualTo: userId)
            .limit(100)
            .get(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );

      final totalSubmitted = myReportsSnap.docs.length;
      int verifiedReports = 0;
      int refutedReports = 0;

      for (final doc in myReportsSnap.docs) {
        final data = doc.data();
        final verifiedBy = (data['verifiedBy'] as List?) ?? [];
        final refutedBy = (data['refutedBy'] as List?) ?? [];
        if (verifiedBy.length >= 2 || (verifiedBy.length > refutedBy.length && verifiedBy.isNotEmpty)) {
          verifiedReports++;
        }
        if (refutedBy.length > verifiedBy.length) {
          refutedReports++;
        }
      }

      final verificationsGivenSnap = await RetryUtils.retry(
        () => _db
            .collection('outbreak_reports')
            .where('verifiedBy', arrayContains: userId)
            .count()
            .get(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );

      final verificationsGiven = verificationsGivenSnap.count ?? 0;

      return {
        'totalSubmitted': totalSubmitted,
        'verifiedReports': verifiedReports,
        'verificationsGiven': verificationsGiven,
        'refutedReports': refutedReports,
      };
    } catch (e) {
      AppLogger.w('FirestoreService: getReporterTrustStats failed: $e');
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
    return _db
        .collection('treatments')
        .where('userId', isEqualTo: userId)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList())
        .handleError((error) {
          throw ServerFailure('Failed to stream treatments: $error');
        });
  }

  Future<void> addTreatment(Map<String, dynamic> data) async {
    try {
      await RetryUtils.retry(
        () => _db.collection('treatments').add(data),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to add treatment: $e');
    }
  }

  Future<void> updateTreatment(String id, Map<String, dynamic> data) async {
    try {
      await RetryUtils.retry(
        () => _db.collection('treatments').doc(id).update(data),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to update treatment: $e');
    }
  }

  Future<void> deleteTreatment(String id) async {
    try {
      await RetryUtils.retry(
        () => _db.collection('treatments').doc(id).delete(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to delete treatment: $e');
    }
  }


  // ─── Feedback ─────────────────────────────────────────────────────────
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
        () => _db.collection('feedback').add({
          'userId': userId,
          'detectionId': detectionId,
          'originalLabel': originalLabel,
          'correctedLabel': correctedLabel,
          'imagePath': imagePath,
          'confidence': confidence,
          'modelVersion': modelVersion,
          'timestamp': FieldValue.serverTimestamp(),
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
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
        () => _db.collection('missing_crops').add({
          'userId': userId,
          'suggestedCrop': suggestedCrop,
          'observedSymptoms': observedSymptoms,
          'imagePath': imagePath,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'review_pending',
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to submit missing crop report: $e');
    }
  }

  Future<void> submitTrainingCandidate(Map<String, dynamic> candidateData) async {
    try {
      await RetryUtils.retry(
        () => _db.collection('training_candidates').add({
          ...candidateData,
          'timestamp': FieldValue.serverTimestamp(),
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to submit training candidate: $e');
    }
  }

  /// Submits a moderation report for a community post to the `reported_posts` collection.
  Future<void> reportPost({
    required String postId,
    required String reporterId,
    String? reason,
  }) async {
    try {
      await RetryUtils.retry(
        () => _db.collection('reported_posts').add({
          'postId': postId,
          'reporterId': reporterId,
          'userId': reporterId,
          'reason': reason ?? 'inappropriate_content',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending_review',
        }),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
    } catch (e) {
      throw ServerFailure('Failed to report post: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserExpertRequests(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await RetryUtils.retry(
        () => _db
            .collection('expert_requests')
            .where('userId', isEqualTo: userId)
            .get(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
      return snap.docs.map((d) => {'id': d.id, ...d.data(), 'type': 'expert_request'}).toList();
    } catch (e) {
      AppLogger.w('FirestoreService: getUserExpertRequests error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserMissingCrops(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await RetryUtils.retry(
        () => _db
            .collection('missing_crops')
            .where('userId', isEqualTo: userId)
            .get(),
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
        retryIf: _isFirestoreTransientError,
      );
      return snap.docs.map((d) => {'id': d.id, ...d.data(), 'type': 'missing_crop'}).toList();
    } catch (e) {
      AppLogger.w('FirestoreService: getUserMissingCrops error: $e');
      return [];
    }
  }

  /// Helper to delete all documents returned by a query using [WriteBatch]
  /// chunked up to the Firestore limit of 500 operations per batch.
  Future<void> _deleteQueryInBatches(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return;

    const int maxBatchSize = 500;
    final docs = snapshot.docs;
    for (int i = 0; i < docs.length; i += maxBatchSize) {
      final end = (i + maxBatchSize < docs.length) ? i + maxBatchSize : docs.length;
      final chunk = docs.sublist(i, end);
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Purges all documents owned by [uid] across users, community_posts, treatments, and scans
  /// collections prior to deleting the Auth user.
  Future<void> deleteUserData(String uid) async {
    if (uid.isEmpty) return;
    try {
      // 1. Delete user profile doc
      await _db.collection('users').doc(uid).delete();

      // 2. Delete user's community posts in batches
      await _deleteQueryInBatches(
        _db.collection('community_posts').where('userId', isEqualTo: uid),
      );

      // 3. Delete user's treatments in batches
      await _deleteQueryInBatches(
        _db.collection('treatments').where('userId', isEqualTo: uid),
      );

      // 4. Delete user's cloud scans in batches
      await _deleteQueryInBatches(
        _db.collection('scans').where('userId', isEqualTo: uid),
      );
    } catch (e) {
      AppLogger.e('FirestoreService: deleteUserData error: $e');
      rethrow;
    }
  }
}
