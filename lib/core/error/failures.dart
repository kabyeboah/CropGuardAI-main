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
  const AuthFailure(super.message);
}

final class MLFailure extends Failure {
  const MLFailure(super.message);
}

final class QualityFailure extends Failure {
  final ImageQualityIssue? issue;
  const QualityFailure(this.issue, super.message);
}

final class OODFailure extends Failure {
  const OODFailure([super.message = "This image does not appear to be a crop leaf."]);
}



