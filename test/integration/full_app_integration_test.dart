import 'package:flutter_test/flutter_test.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/models/treatment_plan.dart';
import 'package:cropguard_flutter/domain/models/disease_risk.dart';
import 'package:cropguard_flutter/data/ml/crop_disease_classifier.dart';
import 'package:cropguard_flutter/data/local/pending_sync_queue.dart';
import 'package:cropguard_flutter/core/utils/location_helper.dart';
import 'package:cropguard_flutter/core/utils/agri_weather_utils.dart';
import 'package:cropguard_flutter/core/utils/risk_weighted_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Full Layered End-to-End Integration Test (Phase 19)', () {
    test(
        'complete lifecycle: diagnosis -> offline queueing -> treatment tracking -> outbreak assessment',
        () async {
      // 1. Ingest simulated image scan and create DetectionResult
      final now = DateTime.now();
      final detection = DetectionResult(
        id: 1001,
        userId: 'farmer_integration_1',
        cropType: 'Tomato',
        diseaseLabel: 'tomato_late_blight',
        displayName: 'Tomato Late Blight',
        confidence: 0.92,
        timestamp: now.millisecondsSinceEpoch,
        imagePath:
            '/data/user/0/com.cropguard/app_flutter/scans/tomato_blight_1001.jpg',
        isSynced: false,
        severity: 'high',
        isHealthy: false,
        cause: 'Phytophthora infestans fungus-like pathogen',
        treatments: const [
          'Apply copper-based fungicide or Mancozeb immediately',
          'Prune heavily infected lower leaves and destroy them off-field',
          'Avoid overhead irrigation to reduce canopy humidity',
        ],
      );

      expect(detection.isHealthy, isFalse);
      expect(detection.isDegraded, isFalse);
      expect(detection.severity, 'high');

      // 2. Queue for offline sync
      final syncPayload = {
        'id': detection.id,
        'cropType': detection.cropType,
        'diseaseName': detection.displayName,
        'confidence': detection.confidence,
        'latitude': LocationHelper.coarsen(6.688543, precision: 2),
        'longitude': LocationHelper.coarsen(-1.624412, precision: 2),
        'timestamp': DateTime.fromMillisecondsSinceEpoch(detection.timestamp)
            .toIso8601String(),
      };

      expect(syncPayload['latitude'], 6.69);
      expect(syncPayload['longitude'], -1.62);

      // Verify payload sanitization
      final sanitized = PendingSyncQueue.sanitizePayload(syncPayload);
      expect(sanitized['latitude'], 6.69);

      // 3. Treatment Tracker Plan Lifecycle
      final treatmentPlans = detection.treatments.asMap().entries.map((entry) {
        return TreatmentPlan(
          id: 'plan_${detection.id}_${entry.key}',
          userId: detection.userId,
          detectionId: detection.id,
          cropType: detection.cropType,
          diseaseName: detection.displayName,
          step: entry.value,
          dueDate: now.add(Duration(days: (entry.key + 1) * 3)),
          createdAt: now,
          completed: false,
        );
      }).toList();

      expect(treatmentPlans.length, 3);
      expect(treatmentPlans.every((t) => !t.completed), isTrue);

      final group = TreatmentPlanGroup(
        groupId: 'group_${detection.id}',
        cropType: detection.cropType,
        diseaseName: detection.displayName,
        detectionId: detection.id,
        createdAt: now,
        steps: treatmentPlans,
      );

      expect(group.totalStepsCount, 3);
      expect(group.completedStepsCount, 0);
      expect(group.progress, 0.0);
      expect(group.isCompleted, isFalse);
      expect(group.nextDueDate, isNotNull);

      // Complete first step
      final completedFirstPlan = treatmentPlans[0].copyWith(completed: true);
      final updatedGroup = TreatmentPlanGroup(
        groupId: group.groupId,
        cropType: group.cropType,
        diseaseName: group.diseaseName,
        detectionId: group.detectionId,
        createdAt: group.createdAt,
        steps: [
          completedFirstPlan,
          treatmentPlans[1],
          treatmentPlans[2],
        ],
      );

      expect(updatedGroup.completedStepsCount, 1);
      expect(updatedGroup.progress, closeTo(0.33, 0.01));

      // 4. AgriWeather and Regional Advice Integration
      final northAdvice = AgriWeatherUtils.getPlantingAdvice('North');
      final southAdvice = AgriWeatherUtils.getPlantingAdvice('South');
      expect(northAdvice['status'], isNotEmpty);
      expect(southAdvice['status'], isNotEmpty);

      // 5. Risk-weighted classification checks
      final candidates = <TopCandidate>[
        (label: 'Tomato___Late_blight', confidence: 0.55),
        (label: 'Tomato___Early_blight', confidence: 0.45),
      ];
      final adjusted = RiskWeightedClassifier.adjustCandidatesWithRegionalRisk(
        candidates: candidates,
        regionalRisks: [
          const DiseaseRisk(
            type: DiseaseRiskType.lateBlight,
            level: RiskLevel.high,
            humidity: 85,
            temp: 22,
            hasNearbyOutbreak: true,
          ),
        ],
      );
      expect(adjusted.first.label, 'Tomato___Late_blight');
      expect(adjusted.first.confidence, greaterThan(0.55));
    });
  });
}
