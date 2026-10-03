import 'relay_error.dart';

/// A small sealed `Result<T>` — `Ok<T>` or `Err<RelayError>`. No `dartz`,
/// no `fpdart`: the constitution rejects ceremony, and two variants over
/// one field each is not worth a dependency.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);

  final RelayError error;
}
