import '../utils/image_quality_analyzer.dart';

abstract class Failure {
  final String message;
  Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  ServerFailure(super.message);
}

class CacheFailure extends Failure {
  CacheFailure(super.message);
}

class AuthFailure extends Failure {
  AuthFailure(super.message);
}

class MLFailure extends Failure {
  MLFailure(super.message);
}

class QualityFailure extends Failure {
  final ImageQualityIssue? issue;
  QualityFailure(this.issue, super.message);
}

