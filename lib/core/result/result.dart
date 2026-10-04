import 'package:furnexa/core/error/app_exception.dart';

sealed class Result<T> {
  const Result._();

  bool get isSuccess;
  T get value;
  AppException get error;

  factory Result.success(T value) => SuccessResult<T>(value);

  factory Result.failure(AppException error) => FailureResult<T>(error);
}

class SuccessResult<T> extends Result<T> {
  const SuccessResult(this.value) : super._();

  @override
  final T value;

  @override
  bool get isSuccess => true;

  @override
  AppException get error => throw StateError('This result is a success and has no error');
}

class FailureResult<T> extends Result<T> {
  const FailureResult(this.error) : super._();

  @override
  final AppException error;

  @override
  bool get isSuccess => false;

  @override
  T get value => throw StateError('This result is a failure and has no value');
}
