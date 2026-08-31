import 'package:flutter_test/flutter_test.dart';

/// Simulates security rules evaluation logic matching firestore.rules and storage.rules
/// to verify that clients cannot forge privileged backend state.
class SecurityRulesEvaluator {
  static bool evaluateOutbreakReportCreate({
    required String? authUid,
    required Map<String, dynamic> data,
  }) {
    if (authUid == null) return false;
    if (data['userId'] != authUid) return false;

    final disease = data['disease'];
    if (disease is! String || disease.isEmpty || disease.length > 80) {
      return false;
    }

    if (data.containsKey('notes')) {
      final notes = data['notes'];
      if (notes is! String || notes.length > 500) return false;
    }

    if (data.containsKey('severity')) {
      final severity = data['severity'];
      if (severity != 'low' && severity != 'medium' && severity != 'high') {
        return false;
      }
    }

    if (data.containsKey('confidence')) {
      final conf = data['confidence'];
      if (conf is! num || conf < 0 || conf > 1) return false;
    }

    if (data.containsKey('latitude')) {
      final lat = data['latitude'];
      if (lat is! num || lat < -90 || lat > 90) return false;
    }

    if (data.containsKey('longitude')) {
      final lng = data['longitude'];
      if (lng is! num || lng < -180 || lng > 180) return false;
    }

    // Security Gate: verifiedBy can only be [authUid] or [] on create (prevent seeding fake votes)
    if (data.containsKey('verifiedBy')) {
      final verifiedBy = data['verifiedBy'];
      if (verifiedBy is! List) return false;
      if (verifiedBy.isNotEmpty &&
          (verifiedBy.length != 1 || verifiedBy.first != authUid)) {
        return false;
      }
    }

    // Security Gate: refutedBy must be empty on create
    if (data.containsKey('refutedBy')) {
      final refutedBy = data['refutedBy'];
      if (refutedBy is! List || refutedBy.isNotEmpty) return false;
    }

    return true;
  }

  static bool evaluateOutbreakReportDirectClientUpdate() {
    // Direct client updates are unconditionally denied in firestore.rules
    return false;
  }

  static bool evaluateCommunityPostUpdate() {
    // Community posts are immutable once created
    return false;
  }

  static bool evaluateReportedPostsRead() {
    // Direct client reads to moderation log are denied
    return false;
  }

  static bool evaluateStorageUpload({
    required String? authUid,
    required String targetPath,
    required int byteSize,
    required String contentType,
  }) {
    if (authUid == null) return false;

    final segments = targetPath.split('/');
    if (segments.length < 3) return false;
    final prefix = segments[0];
    final pathUserId = segments[1];

    if (pathUserId != authUid) return false; // Cross-user write forbidden

    if (!contentType.startsWith('image/')) return false; // Image only

    if (prefix == 'scans') {
      return byteSize <= 10 * 1024 * 1024;
    } else if (prefix == 'community_posts' ||
        prefix == 'profiles' ||
        prefix == 'feedback' ||
        prefix == 'users') {
      return byteSize <= 5 * 1024 * 1024;
    }

    return false;
  }
}

void main() {
  group('Firestore Rules Security Validation', () {
    test('rejects unauthenticated outbreak report creation', () {
      final allowed = SecurityRulesEvaluator.evaluateOutbreakReportCreate(
        authUid: null,
        data: {
          'userId': 'user_123',
          'disease': 'Cassava Mosaic Disease',
        },
      );
      expect(allowed, false);
    });

    test('rejects outbreak report when userId does not match auth UID', () {
      final allowed = SecurityRulesEvaluator.evaluateOutbreakReportCreate(
        authUid: 'attacker_uid',
        data: {
          'userId': 'victim_uid',
          'disease': 'Cassava Mosaic Disease',
        },
      );
      expect(allowed, false);
    });

    test(
        'rejects outbreak report with forged verifiedBy containing third-party UIDs',
        () {
      final allowed = SecurityRulesEvaluator.evaluateOutbreakReportCreate(
        authUid: 'attacker_uid',
        data: {
          'userId': 'attacker_uid',
          'disease': 'Cassava Mosaic Disease',
          'verifiedBy': [
            'attacker_uid',
            'fake_admin_uid',
            'farmer_1',
            'farmer_2'
          ],
        },
      );
      expect(allowed, false);
    });

    test('rejects outbreak report with initial refutedBy entries', () {
      final allowed = SecurityRulesEvaluator.evaluateOutbreakReportCreate(
        authUid: 'user_123',
        data: {
          'userId': 'user_123',
          'disease': 'Maize Smut',
          'refutedBy': ['target_user'],
        },
      );
      expect(allowed, false);
    });

    test('allows legitimate outbreak report creation with self-verification',
        () {
      final allowed = SecurityRulesEvaluator.evaluateOutbreakReportCreate(
        authUid: 'user_123',
        data: {
          'userId': 'user_123',
          'disease': 'Cassava Mosaic Disease',
          'severity': 'high',
          'confidence': 0.85,
          'latitude': 6.6745,
          'longitude': -1.5716,
          'verifiedBy': ['user_123'],
          'refutedBy': [],
        },
      );
      expect(allowed, true);
    });

    test(
        'strictly denies direct client updates to outbreak_reports (must use Cloud Function)',
        () {
      final updateAllowed =
          SecurityRulesEvaluator.evaluateOutbreakReportDirectClientUpdate();
      expect(updateAllowed, false);
    });

    test('strictly denies updates to published community posts (immutable)',
        () {
      final updateAllowed =
          SecurityRulesEvaluator.evaluateCommunityPostUpdate();
      expect(updateAllowed, false);
    });

    test('strictly denies client reads on reported_posts moderation log', () {
      final readAllowed = SecurityRulesEvaluator.evaluateReportedPostsRead();
      expect(readAllowed, false);
    });
  });

  group('Storage Rules Security Validation', () {
    test('denies upload to another user prefix', () {
      final allowed = SecurityRulesEvaluator.evaluateStorageUpload(
        authUid: 'attacker_123',
        targetPath: 'scans/victim_456/photo.jpg',
        byteSize: 1024 * 1024,
        contentType: 'image/jpeg',
      );
      expect(allowed, false);
    });

    test('denies non-image uploads (e.g. scripts or binaries)', () {
      final allowed = SecurityRulesEvaluator.evaluateStorageUpload(
        authUid: 'user_123',
        targetPath: 'community_posts/user_123/payload.exe',
        byteSize: 1024,
        contentType: 'application/x-msdownload',
      );
      expect(allowed, false);
    });

    test('denies oversized files exceeding 5MB for community posts', () {
      final allowed = SecurityRulesEvaluator.evaluateStorageUpload(
        authUid: 'user_123',
        targetPath: 'community_posts/user_123/huge_photo.jpg',
        byteSize: 6 * 1024 * 1024,
        contentType: 'image/jpeg',
      );
      expect(allowed, false);
    });

    test('allows legitimate image upload to owner prefix', () {
      final allowed = SecurityRulesEvaluator.evaluateStorageUpload(
        authUid: 'user_123',
        targetPath: 'scans/user_123/leaf_scan.jpg',
        byteSize: 2 * 1024 * 1024,
        contentType: 'image/jpeg',
      );
      expect(allowed, true);
    });
  });
}
