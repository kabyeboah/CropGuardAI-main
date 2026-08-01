import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/background_tasks.dart';
import '../../../core/utils/scan_severity.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/remote/firebase_auth_service.dart';
import '../../../data/remote/firestore_service.dart';
import '../../../domain/models/treatment_plan.dart';

/// Request to auto-create a treatment plan when the tracker opens — passed as
/// go_router `extra` (e.g. from the disease library "Start Plan" action).
class TreatmentSeed {
  final String cropType;
  final String diseaseName;
  final List<String> steps;
  final String severity;

  const TreatmentSeed({
    required this.cropType,
    required this.diseaseName,
    required this.steps,
    this.severity = ScanSeverity.moderate,
  });
}

class TreatmentTrackerProvider extends ChangeNotifier {
  final DatabaseHelper _db;
  final FirebaseAuthService _auth;
  final FirestoreService _firestore;

  TreatmentTrackerProvider(
    this._db,
    this._auth,
    this._firestore, {
    TreatmentSeed? seed,
  }) {
    if (seed != null) {
      _seedThenLoad(seed);
    } else {
      _load();
    }
  }

  List<TreatmentPlan> plans = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  final int _pageSize = 100;

  int pendingCount = 0;
  int completedCount = 0;
  String? error;

  // Route-scoped provider: async loads can finish after the screen is popped.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// True once a plan requested via [TreatmentSeed] has been created, so the
  /// screen can confirm it to the user.
  bool seededPlan = false;

  Future<void> _seedThenLoad(TreatmentSeed seed) async {
    await addTreatmentPlan(
      crop: seed.cropType,
      disease: seed.diseaseName,
      steps: seed.steps,
      severity: seed.severity,
    );
    seededPlan = true;
    _safeNotify();
  }

  /// Returns true exactly once after a seeded plan was created, so the screen
  /// can show a one-time confirmation without re-triggering on later rebuilds.
  bool consumeSeededFlag() {
    if (!seededPlan) return false;
    seededPlan = false;
    return true;
  }

  String get _userId => _auth.currentUserId;
  bool get _isGuest => _userId == 'guest';

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      isLoading = true;
      hasMore = true;
      plans.clear();
      _safeNotify();
    } else {
      if (!hasMore || isLoadingMore) return;
      isLoadingMore = true;
      _safeNotify();
    }

    error = null;
    try {
      final newPlans = await _db.getAllTreatments(
        userId: _userId,
        limit: _pageSize,
        offset: plans.length,
      );

      plans.addAll(newPlans);
      hasMore = newPlans.length == _pageSize;

      pendingCount = await _db.getPendingTreatmentsCount(userId: _userId);
      completedCount = await _db.getCompletedTreatmentsCount(userId: _userId);
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    isLoadingMore = false;
    _safeNotify();
  }

  /// Day offsets (from today) for [stepCount] treatment steps, spaced by
  /// disease [severity]. Severe diseases need urgent action, so their steps
  /// start the same day and are scheduled tightly; milder cases are spread out.
  static List<int> _scheduleForSeverity(String severity, int stepCount) {
    final int firstDay;
    final int interval;
    switch (severity.toLowerCase()) {
      case ScanSeverity.severe:
        firstDay = 0; // act today
        interval = 1;
        break;
      case ScanSeverity.early:
        firstDay = 1;
        interval = 3;
        break;
      case ScanSeverity.moderate:
      default: // diseased / warning / unclear → treat with moderate urgency
        firstDay = 1;
        interval = 2;
        break;
    }
    return [for (var i = 0; i < stepCount; i++) firstDay + i * interval];
  }

  Future<void> addTreatmentPlan({
    required String crop,
    required String disease,
    required List<String> steps,
    String severity = ScanSeverity.moderate,
    int detectionId = 0,
  }) async {
    final now = DateTime.now();

    // Use every treatment step (not just the first three), then always end
    // with a monitoring step so the plan closes on a re-check.
    final planSteps = [
      for (final s in steps)
        if (s.trim().isNotEmpty) s.trim(),
    ];
    if (planSteps.isEmpty) {
      planSteps.add('Monitor $disease and consult an extension officer.');
    }
    planSteps.add('Re-scan to check whether $disease has improved.');

    final dueDays = _scheduleForSeverity(severity, planSteps.length);

    for (var i = 0; i < planSteps.length; i++) {
      final dueDate = now.add(Duration(days: dueDays[i]));
      final plan = TreatmentPlan(
        id: '',
        userId: _userId,
        detectionId: detectionId,
        cropType: crop,
        diseaseName: disease,
        step: planSteps[i],
        completed: false,
        dueDate: dueDate,
        createdAt: now,
      );

      final id = await _db.insertTreatment(plan);
      unawaited(BackgroundTaskHelper.scheduleReminder(
        disease,
        dueDays[i],
        Duration(days: dueDays[i]),
      ));

      if (!_isGuest) {
        unawaited(
          _firestore.addTreatment({
            ...plan.copyWith(completed: false).toMap(),
            'id': id,
          }),
        );
      }
    }

    await _load();
  }

  Future<void> addFromDetection({
    required int detectionId,
    required String cropType,
    required String diseaseName,
    required List<String> treatmentSteps,
    String severity = ScanSeverity.moderate,
  }) async {
    await addTreatmentPlan(
      crop: cropType,
      disease: diseaseName,
      steps: treatmentSteps,
      severity: severity,
      detectionId: detectionId,
    );
  }

  /// Computes compiled treatment plan groups from the loaded steps list.
  List<TreatmentPlanGroup> get planGroups {
    final Map<String, TreatmentPlanGroup> groupsMap = {};

    for (final step in plans) {
      final cropClean = step.cropType.trim().toLowerCase();
      final diseaseClean = step.diseaseName.trim().toLowerCase();
      final String key = step.detectionId > 0
          ? 'det_${step.detectionId}'
          : '${cropClean}_$diseaseClean';

      if (!groupsMap.containsKey(key)) {
        groupsMap[key] = TreatmentPlanGroup(
          groupId: key,
          cropType: step.cropType,
          diseaseName: step.diseaseName,
          detectionId: step.detectionId,
          createdAt: step.createdAt,
          steps: [],
        );
      }
      groupsMap[key]!.steps.add(step);
    }

    // Sort steps within each group by due date
    for (final group in groupsMap.values) {
      group.steps.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    }

    final groups = groupsMap.values.toList();
    // Sort groups: active groups first (by most recent), then completed groups
    groups.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return groups;
  }


  List<TreatmentPlanGroup> get activeGroups =>
      planGroups.where((g) => !g.isCompleted).toList();

  List<TreatmentPlanGroup> get completedGroups =>
      planGroups.where((g) => g.isCompleted).toList();

  Future<void> toggleStepById(String stepId) async {
    final index = plans.indexWhere((p) => p.id == stepId);
    if (index != -1) {
      await toggleComplete(index);
    }
  }

  Future<void> toggleComplete(int index) async {
    final plan = plans[index];
    final updated = !plan.completed;
    await _db.updateTreatmentCompleted(plan.id, updated);
    plans[index] = plan.copyWith(completed: updated);

    // Keep header counts in sync immediately in-memory
    if (updated) {
      pendingCount = (pendingCount - 1).clamp(0, 999999);
      completedCount++;
    } else {
      pendingCount++;
      completedCount = (completedCount - 1).clamp(0, 999999);
    }
    _safeNotify();

    if (!_isGuest) {
      unawaited(
        _firestore.updateTreatment(plan.id, {'completed': updated ? 1 : 0}),
      );
    }
  }

  Future<void> deletePlan(String id) async {
    await _db.deleteTreatment(id);
    if (!_isGuest) {
      unawaited(_firestore.deleteTreatment(id));
    }
    await _load(reset: true);
  }

  Future<void> deletePlanGroup(TreatmentPlanGroup group) async {
    for (final step in group.steps) {
      await _db.deleteTreatment(step.id);
      if (!_isGuest) {
        unawaited(_firestore.deleteTreatment(step.id));
      }
    }
    await _load(reset: true);
  }

  Future<void> refresh() => _load(reset: true);

  Future<void> loadMore() => _load(reset: false);
}

