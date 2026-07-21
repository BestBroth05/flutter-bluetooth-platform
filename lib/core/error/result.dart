import 'ble_failure.dart';

/// Lightweight success/failure wrapper used by application and domain ports.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T get requireValue => switch (this) {
    Success(:final value) => value,
    Failure(:final failure) => throw failure,
  };

  BleFailure get requireFailure => switch (this) {
    Failure(:final failure) => failure,
    Success() => throw StateError('Result is a success.'),
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(BleFailure failure) onFailure,
  }) {
    return switch (this) {
      Success(:final value) => onSuccess(value),
      Failure(:final failure) => onFailure(failure),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final BleFailure failure;
}
