import '../../core/utils/result.dart';
import '../models/risk_assessment.dart';

abstract class IRiskRepository {
  Future<Result<RiskAssessment>> getRiskForLocation({
    required double lat,
    required double lon,
    String? cropType,
  });
}
