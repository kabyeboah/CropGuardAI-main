import '../../../core/utils/result.dart';
import '../../models/risk_assessment.dart';
import '../../repositories/i_risk_repository.dart';

class GetRiskAssessmentUseCase {
  final IRiskRepository _repository;

  GetRiskAssessmentUseCase(this._repository);

  Future<Result<RiskAssessment>> call({
    required double lat,
    required double lon,
    String? cropType,
  }) {
    return _repository.getRiskForLocation(
      lat: lat,
      lon: lon,
      cropType: cropType,
    );
  }
}
