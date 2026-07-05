import '../error/failures.dart';

class Result<T> {
  final T? data;
  final Failure? failure;

  Result._({this.data, this.failure});

  factory Result.success(T data) => Result._(data: data);
  factory Result.error(Failure failure) => Result._(failure: failure);

  bool get isSuccess => failure == null;
  bool get isError => failure != null;

  void fold(void Function(T data) onSuccess, void Function(Failure failure) onError) {
    if (isSuccess) {
      onSuccess(data as T);
    } else {
      onError(failure!);
    }
  }
}
