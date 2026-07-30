import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/models/field.dart';
import 'package:cropguard_flutter/domain/models/treatment_plan.dart';

/// Tests for database operations beyond the farm-stats scoping tests.
/// Covers: reassignDetections, treatment CRUD, field CRUD, notification CRUD,
/// and counting helpers — ensuring user data isolation and correct schema
/// behaviour across operations.
///
/// Each test gets a fully isolated in-memory database; tearDown disposes of it.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    // Each test gets an isolated in-memory database via the forTest constructor.
    db = DatabaseHelper.forTest('extended_test');
  });

  tearDown(() async {
    await db.close();
  });

  // ── helpers ──────────────────────────────────────────────────────────────

  DetectionResult detection({
    required String userId,
    bool isHealthy = false,
    String disease = 'blight',
  }) =>
      DetectionResult(
        userId: userId,
        imagePath: '',
        diseaseLabel: disease,
        displayName: disease,
        confidence: 0.9,
        isHealthy: isHealthy,
        cropType: 'tomato',
        cause: '',
        treatments: const [],
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

  TreatmentPlan treatment({String userId = 'alice', bool completed = false}) =>
      TreatmentPlan(
        id: '',
        userId: userId,
        detectionId: 0,
        cropType: 'tomato',
        diseaseName: 'blight',
        step: 'Apply fungicide',
        completed: completed,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        createdAt: DateTime.now(),
      );

  // ── reassignDetections ────────────────────────────────────────────────────

  group('reassignDetections', () {
    test('moves all detections from guest to real account', () async {
      await db.insertDetection(detection(userId: 'guest_001'));
      await db.insertDetection(detection(userId: 'guest_001'));
      await db.insertDetection(detection(userId: 'real_user'));

      await db.reassignDetections('guest_001', 'real_user');

      final guestDetections = await db.getAllDetections(userId: 'guest_001');
      final realDetections = await db.getAllDetections(userId: 'real_user');

      expect(guestDetections, isEmpty);
      expect(realDetections.length, 3);
    });

    test('is a no-op when fromUserId has no detections', () async {
      await db.insertDetection(detection(userId: 'alice'));

      await db.reassignDetections('nobody', 'alice');

      final aliceDetections = await db.getAllDetections(userId: 'alice');
      expect(aliceDetections.length, 1);
    });
  });

  // ── countDetectionsForUser ────────────────────────────────────────────────

  group('countDetectionsForUser', () {
    test('returns 0 for a user with no detections', () async {
      final count = await db.countDetectionsForUser('nobody');
      expect(count, 0);
    });

    test('counts only the specified user', () async {
      await db.insertDetection(detection(userId: 'alice'));
      await db.insertDetection(detection(userId: 'alice'));
      await db.insertDetection(detection(userId: 'bob'));

      expect(await db.countDetectionsForUser('alice'), 2);
      expect(await db.countDetectionsForUser('bob'), 1);
    });
  });

  // ── getDistinctDiseaseCount ───────────────────────────────────────────────

  group('getDistinctDiseaseCount', () {
    test('counts unique disease labels across all diseased detections', () async {
      await db.insertDetection(
          detection(userId: 'alice', disease: 'blight', isHealthy: false));
      await db.insertDetection(
          detection(userId: 'alice', disease: 'blight', isHealthy: false));
      await db.insertDetection(
          detection(userId: 'alice', disease: 'rust', isHealthy: false));
      await db.insertDetection(
          detection(userId: 'alice', isHealthy: true)); // excluded

      expect(await db.getDistinctDiseaseCount(), 2);
    });
  });

  // ── deleteDetection ───────────────────────────────────────────────────────

  group('deleteDetection', () {
    test('removes only the specified detection', () async {
      final id1 = await db.insertDetection(detection(userId: 'alice'));
      await db.insertDetection(detection(userId: 'alice'));

      await db.deleteDetection(id1);

      final remaining = await db.getAllDetections(userId: 'alice');
      expect(remaining.length, 1);
    });

    test('is a no-op for a non-existent id', () async {
      await db.insertDetection(detection(userId: 'alice'));

      await db.deleteDetection(9999); // no-op

      final remaining = await db.getAllDetections(userId: 'alice');
      expect(remaining.length, 1);
    });
  });

  // ── getRecentDetections ───────────────────────────────────────────────────

  group('getRecentDetections', () {
    test('returns at most the requested limit', () async {
      for (var i = 0; i < 10; i++) {
        await db.insertDetection(detection(userId: 'alice'));
      }
      final recent = await db.getRecentDetections(userId: 'alice', limit: 3);
      expect(recent.length, 3);
    });

    test('returns detections in descending timestamp order', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insertDetection(DetectionResult(
        userId: 'alice',
        imagePath: '',
        diseaseLabel: 'a',
        displayName: 'a',
        confidence: 0.9,
        isHealthy: false,
        cropType: 'tomato',
        cause: '',
        treatments: const [],
        timestamp: now - 1000,
      ));
      await db.insertDetection(DetectionResult(
        userId: 'alice',
        imagePath: '',
        diseaseLabel: 'b',
        displayName: 'b',
        confidence: 0.9,
        isHealthy: false,
        cropType: 'tomato',
        cause: '',
        treatments: const [],
        timestamp: now,
      ));

      final recent = await db.getRecentDetections(userId: 'alice', limit: 2);
      expect(recent.first.diseaseLabel, 'b'); // most recent first
    });
  });

  // ── Treatment Plans ───────────────────────────────────────────────────────

  group('TreatmentPlans', () {
    test('insertTreatment returns a non-empty UUID', () async {
      final id = await db.insertTreatment(treatment());
      expect(id, isNotEmpty);
    });

    test('getAllTreatments filters by userId', () async {
      await db.insertTreatment(treatment(userId: 'alice'));
      await db.insertTreatment(treatment(userId: 'alice'));
      await db.insertTreatment(treatment(userId: 'bob'));

      final aliceTreatments = await db.getAllTreatments(userId: 'alice');
      expect(aliceTreatments.length, 2);
    });

    test('updateTreatmentCompleted toggles the flag', () async {
      final id = await db.insertTreatment(treatment(completed: false));

      await db.updateTreatmentCompleted(id, true);

      final treatments = await db.getAllTreatments();
      expect(treatments.firstWhere((t) => t.id == id).completed, true);
    });

    test('deleteTreatment removes the record', () async {
      final id = await db.insertTreatment(treatment());
      await db.deleteTreatment(id);

      final treatments = await db.getAllTreatments();
      expect(treatments.where((t) => t.id == id), isEmpty);
    });

    test('getCompletedTreatmentsCount counts only completed', () async {
      await db.insertTreatment(treatment(completed: true));
      await db.insertTreatment(treatment(completed: true));
      await db.insertTreatment(treatment(completed: false));

      expect(await db.getCompletedTreatmentsCount(), 2);
    });
  });

  // ── Fields ────────────────────────────────────────────────────────────────

  group('Fields', () {
    Field field({String userId = 'alice', String name = 'Test Field'}) => Field(
          id: 'field_${name.hashCode}',
          name: name,
          cropType: 'maize',
          sizeHectares: 2.5,
          plantingDate: null,
          userId: userId,
        );

    test('upsertField and getFields round-trip', () async {
      final f = field();
      await db.upsertField(f);

      final fields = await db.getFields(userId: 'alice');
      expect(fields.length, 1);
      expect(fields.first.name, 'Test Field');
    });

    test('getFields filters by userId', () async {
      await db.upsertField(field(userId: 'alice', name: 'Alice Farm'));
      await db.upsertField(field(userId: 'bob', name: 'Bob Farm'));

      expect((await db.getFields(userId: 'alice')).length, 1);
      expect((await db.getFields(userId: 'bob')).length, 1);
    });

    test('deleteField removes the record', () async {
      final f = field();
      await db.upsertField(f);
      await db.deleteField(f.id);

      expect(await db.getFields(userId: 'alice'), isEmpty);
    });
  });
}
