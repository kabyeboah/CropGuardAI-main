import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/data/remote/firestore_service.dart';
import 'package:cropguard_flutter/data/remote/firebase_auth_service.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/repositories/profile_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFirestoreService extends Mock implements FirestoreService {}
class MockFirebaseAuthService extends Mock implements FirebaseAuthService {}
class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late MockFirebaseAuthService mockAuth;
  late MockDatabaseHelper mockDbHelper;
  late MockSharedPreferences mockPrefs;
  late MockFirestoreService mockFirestore;
  late ProfileRepositoryImpl repo;

  setUp(() {
    mockAuth = MockFirebaseAuthService();
    mockDbHelper = MockDatabaseHelper();
    mockPrefs = MockSharedPreferences();
    mockFirestore = MockFirestoreService();
    repo = ProfileRepositoryImpl(
      mockAuth,
      mockDbHelper,
      mockPrefs,
      mockFirestore,
    );
  });

  group('ProfileRepositoryImpl.getReporterTrustStats', () {
    test('returns calculated trust stats from firestore stats map', () async {
      when(() => mockFirestore.getReporterTrustStats('user-123')).thenAnswer(
        (_) async => {
          'totalSubmitted': 12,
          'verifiedReports': 10,
          'verificationsGiven': 25,
          'refutedReports': 1,
        },
      );

      final result = await repo.getReporterTrustStats('user-123');

      expect(result.isSuccess, isTrue);
      final stats = result.data!;
      expect(stats.totalSubmittedReports, 12);
      expect(stats.verifiedReportsCount, 10);
      expect(stats.verificationsGivenCount, 25);
      // (10 * 10) + (25 * 2) - (1 * 5) = 100 + 50 - 5 = 145
      expect(stats.trustScore, 145);
      expect(stats.reputationBadgeTitle, '🛡️ Trusted Sentinel');
    });

    test('returns server failure on firestore exception', () async {
      when(() => mockFirestore.getReporterTrustStats('user-err'))
          .thenThrow(Exception('network error'));

      final result = await repo.getReporterTrustStats('user-err');

      expect(result.isError, isTrue);
      expect(result.failure?.message, contains('network error'));
    });
  });
}
