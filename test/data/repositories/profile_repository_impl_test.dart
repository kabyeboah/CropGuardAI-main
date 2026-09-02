import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/data/remote/supabase_auth_service.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/repositories/profile_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSupabaseAuthService extends Mock implements SupabaseAuthService {}

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late MockSupabaseAuthService mockAuth;
  late MockDatabaseHelper mockDbHelper;
  late MockSharedPreferences mockPrefs;
  late ProfileRepositoryImpl repo;

  setUp(() {
    mockAuth = MockSupabaseAuthService();
    mockDbHelper = MockDatabaseHelper();
    mockPrefs = MockSharedPreferences();
    repo = ProfileRepositoryImpl(
      mockAuth,
      mockDbHelper,
      mockPrefs,
    );
  });

  group('ProfileRepositoryImpl.getReporterTrustStats', () {
    test('returns calculated trust stats', () async {
      final result = await repo.getReporterTrustStats('user-123');

      expect(result.isSuccess, isTrue);
      final stats = result.data!;
      expect(stats.totalSubmittedReports, 0);
    });
  });
}
