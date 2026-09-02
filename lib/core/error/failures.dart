import '../utils/image_quality_analyzer.dart';

sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network connection failed.']);
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

final class AuthFailure extends Failure {
  final String? code;
  const AuthFailure(super.message, {this.code});
}

final class MLFailure extends Failure {
  final String code;
  const MLFailure(super.message, {this.code = 'ML_FAILURE'});
}

final class ModelLoadFailure extends MLFailure {
  const ModelLoadFailure(
      [super.message = 'Failed to load machine learning model or assets.'])
      : super(code: 'MODEL_LOAD_FAILED');
}

final class ModelContractFailure extends MLFailure {
  const ModelContractFailure(
      [super.message =
          'Model tensor dimensions or types violate expected metadata contract.'])
      : super(code: 'MODEL_CONTRACT_FAILED');
}

final class ModelInputFailure extends MLFailure {
  const ModelInputFailure(
      [super.message =
          'Input image cannot be decoded or processed into model tensor.'])
      : super(code: 'MODEL_INPUT_INVALID');
}

final class ModelInferenceFailure extends MLFailure {
  const ModelInferenceFailure(
      [super.message = 'Model interpreter failed during inference.'])
      : super(code: 'MODEL_INFERENCE_FAILED');
}

final class LabelContractFailure extends MLFailure {
  const LabelContractFailure(
      [super.message =
          'Label definitions mismatch model output class contract.'])
      : super(code: 'LABEL_CONTRACT_FAILED');
}

final class QualityFailure extends Failure {
  final ImageQualityIssue? issue;
  final String code;
  const QualityFailure(this.issue, super.message,
      {this.code = 'IMAGE_QUALITY_FAILED'});
}

final class OODFailure extends Failure {
  final String code;
  const OODFailure([
    super.message = "This image does not appear to be a crop leaf.",
    this.code = 'OOD_REJECTED',
  ]);
}

final class ConfidenceAbstentionFailure extends Failure {
  final String code;
  const ConfidenceAbstentionFailure([
    super.message =
        "Model confidence is below the diagnostic threshold; abstaining from standalone diagnosis.",
    this.code = 'CONFIDENCE_ABSTENTION',
  ]);
}

final class ImageSecurityFailure extends Failure {
  final String code;
  const ImageSecurityFailure([
    super.message = 'The requested image URL was blocked for security reasons.',
    this.code = 'IMAGE_SECURITY_BLOCKED',
  ]);
}

final class ImageDownloadLimitFailure extends Failure {
  final String code;
  const ImageDownloadLimitFailure([
    super.message =
        'The image exceeds the maximum permitted download size (15 MB).',
    this.code = 'IMAGE_DOWNLOAD_TOO_LARGE',
  ]);
}

final class NonImageFailure extends Failure {
  final String code;
  const NonImageFailure([
    super.message =
        'The URL or data source does not contain valid image content.',
    this.code = 'NOT_AN_IMAGE',
  ]);
}

final class ImageBombFailure extends Failure {
  final String code;
  const ImageBombFailure([
    super.message =
        'Image dimensions or uncompressed memory size exceeds safe limits.',
    this.code = 'IMAGE_DECOMPRESSION_BOMB',
  ]);
}
