import '../../../core/utils/result.dart';
import '../../models/detection_result.dart';
import 'scan_crop_usecase.dart';

/// Use case for batch scanning multiple crop leaf images.
class ScanBatchUseCase {
  final ScanCropUseCase _scanCropUseCase;

  ScanBatchUseCase(this._scanCropUseCase);

  Future<Result<List<DetectionResult>>> call(
    List<String> imagePaths,
    String userId,
  ) async {
    if (imagePaths.isEmpty) {
      return Result.success(const []);
    }

    final results = <DetectionResult>[];
    for (final path in imagePaths) {
      final res = await _scanCropUseCase(path, userId);
      if (res.isSuccess && res.data != null) {
        results.add(res.data!);
      }
    }

    return Result.success(results);
  }
}
