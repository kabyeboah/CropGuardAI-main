import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/utils/scan_severity.dart';
import 'package:cropguard_flutter/domain/models/detection_result.dart';
import 'package:cropguard_flutter/domain/repositories/i_classifier_repository.dart';
import 'package:cropguard_flutter/domain/repositories/i_detection_repository.dart';
import 'package:cropguard_flutter/domain/usecases/scanner/scan_crop_usecase.dart';
import 'package:cropguard_flutter/data/ml/disease_info.dart';
import 'package:cropguard_flutter/core/utils/streak_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClassifierRepository extends Mock implements IClassifierRepository {}
class MockDetectionRepository extends Mock implements IDetectionRepository {}

void main() {
  late ScanCropUseCase useCase;
  late MockClassifierRepository mockClassifier;
  late MockDetectionRepository mockDetection;
  late StreakManager streakManager;

  setUp(() async {
    mockClassifier = MockClassifierRepository();
    mockDetection = MockDetectionRepository();
    SharedPreferences.setMockInitialValues({});
    streakManager = StreakManager(await SharedPreferences.getInstance());
    useCase = ScanCropUseCase(mockClassifier, mockDetection, streakManager);
    
    registerFallbackValue(const DetectionResult(
      userId: 'test',
      imagePath: 'test',
      diseaseLabel: 'test',
      displayName: 'test',
      confidence: 0.9,
      severity: 'test',
      isHealthy: false,
      cropType: 'test',
      cause: 'test',
      treatments: ['test'],
      timestamp: 0,
    ));
  });

  group('ScanCropUseCase severity branching', () {
    const userId = 'user_123';
    const imagePath = 'assets/test_leaf.jpg';

    void setupMockWithDisease(String label, bool isHealthy) {
      final diseaseInfo = DiseaseDatabase.getInfo(label);
      when(() => mockClassifier.classifyFromPath(imagePath)).thenAnswer(
        (_) async => Result.success(Classification(
          label: label,
          confidence: 0.9,
          isHealthy: isHealthy,
          diseaseInfo: diseaseInfo,
        )),
      );

      when(() => mockDetection.saveDetection(any())).thenAnswer(
        (_) async => Result.success(1),
      );
    }

    test('should assign healthy severity when isHealthy is true', () async {
      setupMockWithDisease('Apple___healthy', true);
      
      final result = await useCase(imagePath, userId);
      
      expect(result.data!.severity, ScanSeverity.healthy);
    });

    test('should assign severe severity when database severity is severe', () async {
      setupMockWithDisease('Apple___Black_rot', false);
      
      final result = await useCase(imagePath, userId);
      
      expect(result.data!.severity, ScanSeverity.severe);
    });

    test('should assign moderate severity when database severity is moderate', () async {
      setupMockWithDisease('Apple___Apple_scab', false);
      
      final result = await useCase(imagePath, userId);
      
      expect(result.data!.severity, ScanSeverity.moderate);
    });

    test('should assign early severity when database severity is early', () async {
      setupMockWithDisease('Tomato___Early_blight', false);
      
      final result = await useCase(imagePath, userId);
      
      expect(result.data!.severity, ScanSeverity.early);
    });
  });
}
