import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/error/failures.dart';
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
        maxAttempts: 3,
        timeout: const Duration(seconds: 15),
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
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      throw ServerFailure('Failed to get outbreak reports: $e');
    }
  }

  // ─── Treatment Tracking ───────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> treatmentsStream(String userId) {
    return _db
        .collection('treatments')
        .where('userId', isEqualTo: userId)
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

  // ─── Feedback ─────────────────────────────────────────────────────────
  Future<void> submitFeedback({
    required String userId,
    required int detectionId,
    required String originalLabel,
    required String correctedLabel,
  }) async {
    try {
      await RetryUtils.retry(
        () => _db.collection('feedback').add({
          'userId': userId,
          'detectionId': detectionId,
          'originalLabel': originalLabel,
          'correctedLabel': correctedLabel,
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
}
