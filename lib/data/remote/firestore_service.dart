import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/community_post.dart';

/// Firestore service — replaces Firebase-backed repository implementations
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Community Posts ──────────────────────────────────────────────────
  Stream<List<CommunityPost>> postsStream() {
    return _db
        .collection('community_posts')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommunityPost.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addPost(CommunityPost post) async {
    await _db.collection('community_posts').add(post.toMap());
  }

  // ─── Expert Consultation ──────────────────────────────────────────────
  Future<void> requestExpertHelp({
    required String userId,
    required String detectionId,
    required String message,
    required String diseaseName,
  }) async {
    await _db.collection('expert_requests').add({
      'userId': userId,
      'detectionId': detectionId,
      'message': message,
      'diseaseName': diseaseName,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // ─── Scan Sync ────────────────────────────────────────────────────────

  /// Writes scan data using [docId] as the Firestore document ID.
  /// Using set() instead of add() makes every sync run idempotent: re-running
  /// the background task overwrites the same document rather than duplicating it.
  Future<void> upsertScan(String docId, Map<String, dynamic> scanData) async {
    await _db.collection('scans').doc(docId).set(scanData);
  }

  /// Kept for call-sites outside the background sync path.
  Future<void> uploadScan(Map<String, dynamic> scanData) async {
    await _db.collection('scans').add(scanData);
  }

  // ─── User profile ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> updateUserProfile(
      String uid, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  // ─── Outbreak Map ─────────────────────────────────────────────────────

  /// Submits a crowd-sourced outbreak report. [data] must include a [userId]
  /// field matching the caller's UID so Firestore security rules can validate it.
  Future<void> submitOutbreakReport(Map<String, dynamic> data) async {
    final reportData = {
      ...data,
      'verifiedBy': data['userId'] != null ? [data['userId']] : [],
      'refutedBy': [],
    };
    await _db.collection('outbreak_reports').add(reportData);
  }

  Future<void> verifyOutbreak({
    required String reportId,
    required String userId,
    required bool confirm,
  }) async {
    final docRef = _db.collection('outbreak_reports').doc(reportId);
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
  }

  Future<List<Map<String, dynamic>>> getOutbreakReports() async {
    final snap = await _db
        .collection('outbreak_reports')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ─── Treatment Tracking ───────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> treatmentsStream(String userId) {
    return _db
        .collection('treatments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<void> addTreatment(Map<String, dynamic> data) async {
    await _db.collection('treatments').add(data);
  }

  Future<void> updateTreatment(String id, Map<String, dynamic> data) async {
    await _db.collection('treatments').doc(id).update(data);
  }

  // ─── Feedback ─────────────────────────────────────────────────────────
  Future<void> submitFeedback({
    required String userId,
    required int detectionId,
    required String originalLabel,
    required String correctedLabel,
  }) async {
    await _db.collection('feedback').add({
      'userId': userId,
      'detectionId': detectionId,
      'originalLabel': originalLabel,
      'correctedLabel': correctedLabel,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitCropNotFound({
    required String userId,
    required String suggestedCrop,
    required String observedSymptoms,
    required String imagePath,
  }) async {
    await _db.collection('missing_crops').add({
      'userId': userId,
      'suggestedCrop': suggestedCrop,
      'observedSymptoms': observedSymptoms,
      'imagePath': imagePath,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'review_pending',
    });
  }
}
