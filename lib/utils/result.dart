import 'package:breakbite/domain/app_exception.dart';

/// Outcome of a one-shot operation of a repository or service: [Ok] with a value, or [Err] with an
/// [AppException]. Callers handle both with an exhaustive `switch`; nothing is thrown across layers.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.error(AppException error) = Err<T>;

  bool get isOk => this is Ok<T>;

  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  AppException? get errorOrNull => switch (this) {
    Ok() => null,
    Err(:final error) => error,
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);

  final AppException error;
}
