import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/data/remote/supabase_database_service.dart';
import 'package:cropguard_flutter/domain/models/app_user.dart';
import 'package:cropguard_flutter/domain/models/treatment_plan.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/presentation/screens/treatment_tracker/treatment_tracker_provider.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockIAuthRepository extends Mock implements IAuthRepository {}

class MockSupabaseDatabaseService extends Mock implements SupabaseDatabaseService {}

class FakeTreatmentPlan extends Fake implements TreatmentPlan {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeTreatmentPlan());
  });

  late MockDatabaseHelper mockDb;
  late MockIAuthRepository mockAuthRepo;
  late MockSupabaseDatabaseService mockDatabaseService;

  setUp(() {
    mockDb = MockDatabaseHelper();
    mockAuthRepo = MockIAuthRepository();
    mockDatabaseService = MockSupabaseDatabaseService();

    when(() => mockAuthRepo.currentUser).thenReturn(null);
  });

  group('TreatmentPlanGroup domain model', () {
    test('isCompleted returns true when all steps are completed', () {
      final now = DateTime.now();
      final group = TreatmentPlanGroup(
        groupId: 'g1',
        cropType: 'Apple',
        diseaseName: 'Black Rot',
        detectionId: 101,
        createdAt: now,
        steps: [
          TreatmentPlan(
            id: 's1',
            userId: 'guest',
            detectionId: 101,
            cropType: 'Apple',
            diseaseName: 'Black Rot',
            step: 'Step 1',
            completed: true,
            dueDate: now.add(const Duration(days: 1)),
            createdAt: now,
          ),
          TreatmentPlan(
            id: 's2',
            userId: 'guest',
            detectionId: 101,
            cropType: 'Apple',
            diseaseName: 'Black Rot',
            step: 'Step 2',
            completed: true,
            dueDate: now.add(const Duration(days: 2)),
            createdAt: now,
          ),
        ],
      );

      expect(group.isCompleted, isTrue);
      expect(group.completedStepsCount, 2);
      expect(group.totalStepsCount, 2);
      expect(group.progress, 1.0);
      expect(group.nextDueDate, isNull);
    });

    test('isCompleted returns false when at least one step is pending', () {
      final now = DateTime.now();
      final due1 = now.add(const Duration(days: 1));
      final due2 = now.add(const Duration(days: 2));

      final group = TreatmentPlanGroup(
        groupId: 'g1',
        cropType: 'Maize',
        diseaseName: 'Leaf Blight',
        detectionId: 102,
        createdAt: now,
        steps: [
          TreatmentPlan(
            id: 's1',
            userId: 'guest',
            detectionId: 102,
            cropType: 'Maize',
            diseaseName: 'Leaf Blight',
            step: 'Step 1',
            completed: true,
            dueDate: due1,
            createdAt: now,
          ),
          TreatmentPlan(
            id: 's2',
            userId: 'guest',
            detectionId: 102,
            cropType: 'Maize',
            diseaseName: 'Leaf Blight',
            step: 'Step 2',
            completed: false,
            dueDate: due2,
            createdAt: now,
          ),
        ],
      );

      expect(group.isCompleted, isFalse);
      expect(group.completedStepsCount, 1);
      expect(group.totalStepsCount, 2);
      expect(group.progress, 0.5);
      expect(group.nextDueDate, due2);
    });
  });

  group('TreatmentTrackerProvider grouping', () {
    test(
        'groups raw steps by detectionId and separates active vs completed groups',
        () async {
      final now = DateTime.now();

      final step1 = TreatmentPlan(
        id: 's1',
        userId: 'guest',
        detectionId: 1,
        cropType: 'Apple',
        diseaseName: 'Black Rot',
        step: 'Remove dead wood',
        completed: true,
        dueDate: now,
        createdAt: now,
      );
      final step2 = TreatmentPlan(
        id: 's2',
        userId: 'guest',
        detectionId: 1,
        cropType: 'Apple',
        diseaseName: 'Black Rot',
        step: 'Apply fungicide',
        completed: true,
        dueDate: now.add(const Duration(days: 1)),
        createdAt: now,
      );
      final step3 = TreatmentPlan(
        id: 's3',
        userId: 'guest',
        detectionId: 2,
        cropType: 'Maize',
        diseaseName: 'Blight',
        step: 'Rotate crops',
        completed: false,
        dueDate: now,
        createdAt: now,
      );

      when(() => mockDb.getAllTreatments(
            userId: 'guest',
            limit: 100,
            offset: 0,
          )).thenAnswer((_) async => [step1, step2, step3]);
      when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
          .thenAnswer((_) async => 1);
      when(() => mockDb.getCompletedTreatmentsCount(userId: 'guest'))
          .thenAnswer((_) async => 2);

      final provider =
          TreatmentTrackerProvider(mockDb, mockAuthRepo, mockDatabaseService);
      await Future.delayed(Duration.zero);

      expect(provider.planGroups.length, 2);
      expect(provider.activeGroups.length, 1);
      expect(provider.completedGroups.length, 1);

      expect(provider.completedGroups.first.diseaseName, 'Black Rot');
      expect(provider.activeGroups.first.diseaseName, 'Blight');
    });

    test('deletePlanGroup deletes all steps belonging to that group', () async {
      final now = DateTime.now();
      final step1 = TreatmentPlan(
        id: 's1',
        userId: 'guest',
        detectionId: 10,
        cropType: 'Banana',
        diseaseName: 'Pest',
        step: 'Trap pests',
        completed: false,
        dueDate: now,
        createdAt: now,
      );

      final group = TreatmentPlanGroup(
        groupId: 'det_10',
        cropType: 'Banana',
        diseaseName: 'Pest',
        detectionId: 10,
        createdAt: now,
        steps: [step1],
      );

      when(() => mockDb.getAllTreatments(
            userId: 'guest',
            limit: 100,
            offset: 0,
          )).thenAnswer((_) async => [step1]);
      when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
          .thenAnswer((_) async => 1);
      when(() => mockDb.getCompletedTreatmentsCount(userId: 'guest'))
          .thenAnswer((_) async => 0);
      when(() => mockDb.deleteTreatment('s1')).thenAnswer((_) async {});

      final provider =
          TreatmentTrackerProvider(mockDb, mockAuthRepo, mockDatabaseService);
      await Future.delayed(Duration.zero);

      when(() => mockDb.getAllTreatments(
            userId: 'guest',
            limit: 100,
            offset: 0,
          )).thenAnswer((_) async => []);
      when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
          .thenAnswer((_) async => 0);

      await provider.deletePlanGroup(group);

      verify(() => mockDb.deleteTreatment('s1')).called(1);
      expect(provider.planGroups, isEmpty);
    });

    test(
        'does not throw when currentUser is null and skips firestore sync in guest mode',
        () async {
      when(() => mockAuthRepo.currentUser).thenReturn(null);
      when(() => mockDb.getAllTreatments(
            userId: 'guest',
            limit: 100,
            offset: 0,
          )).thenAnswer((_) async => []);
      when(() => mockDb.getPendingTreatmentsCount(userId: 'guest'))
          .thenAnswer((_) async => 0);
      when(() => mockDb.getCompletedTreatmentsCount(userId: 'guest'))
          .thenAnswer((_) async => 0);
      when(() => mockDb.getFields(userId: 'guest')).thenAnswer((_) async => []);
      when(() => mockDb.insertTreatment(any())).thenAnswer((_) async => '1');

      final provider =
          TreatmentTrackerProvider(mockDb, mockAuthRepo, mockDatabaseService);
      await Future.delayed(Duration.zero);

      await provider.addTreatmentPlan(
        crop: 'Maize',
        disease: 'Blight',
        steps: ['Apply bio-fungicide'],
      );

      verifyNever(() => mockDatabaseService.addTreatment(any()));
    });

    test('skips firestore sync when user is anonymous', () async {
      final anonUser = AppUser(
        id: 'anon_12345',
        email: '',
        displayName: 'Guest Farmer',
        isAnonymous: true,
      );
      when(() => mockAuthRepo.currentUser).thenReturn(anonUser);
      when(() => mockDb.getAllTreatments(
            userId: 'anon_12345',
            limit: 100,
            offset: 0,
          )).thenAnswer((_) async => []);
      when(() => mockDb.getPendingTreatmentsCount(userId: 'anon_12345'))
          .thenAnswer((_) async => 0);
      when(() => mockDb.getCompletedTreatmentsCount(userId: 'anon_12345'))
          .thenAnswer((_) async => 0);
      when(() => mockDb.getFields(userId: 'anon_12345'))
          .thenAnswer((_) async => []);
      when(() => mockDb.insertTreatment(any())).thenAnswer((_) async => '1');

      final provider =
          TreatmentTrackerProvider(mockDb, mockAuthRepo, mockDatabaseService);
      await Future.delayed(Duration.zero);

      await provider.addTreatmentPlan(
        crop: 'Maize',
        disease: 'Blight',
        steps: ['Apply bio-fungicide'],
      );

      verifyNever(() => mockDatabaseService.addTreatment(any()));
    });

    test('syncs to firestore when authenticated user is not anonymous',
        () async {
      final realUser = AppUser(
        id: 'user_real_999',
        email: 'farmer@example.com',
        displayName: 'Real Farmer',
        isAnonymous: false,
      );
      when(() => mockAuthRepo.currentUser).thenReturn(realUser);
      when(() => mockDb.getAllTreatments(
            userId: 'user_real_999',
            limit: 100,
            offset: 0,
          )).thenAnswer((_) async => []);
      when(() => mockDb.getPendingTreatmentsCount(userId: 'user_real_999'))
          .thenAnswer((_) async => 0);
      when(() => mockDb.getCompletedTreatmentsCount(userId: 'user_real_999'))
          .thenAnswer((_) async => 0);
      when(() => mockDb.getFields(userId: 'user_real_999'))
          .thenAnswer((_) async => []);
      when(() => mockDb.insertTreatment(any())).thenAnswer((_) async => '1');
      when(() => mockDatabaseService.addTreatment(any()))
          .thenAnswer((_) async => 'cloud_id_1');

      final provider =
          TreatmentTrackerProvider(mockDb, mockAuthRepo, mockDatabaseService);
      await Future.delayed(Duration.zero);

      await provider.addTreatmentPlan(
        crop: 'Maize',
        disease: 'Blight',
        steps: ['Apply bio-fungicide'],
      );

      verify(() => mockDatabaseService.addTreatment(any()))
          .called(greaterThanOrEqualTo(1));
    });
  });
}
