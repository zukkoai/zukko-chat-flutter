# Result type

A sealed `Result<T>` forces the UI to handle both branches.

```dart
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;
}

extension ResultX<T> on Result<T> {
  R fold<R>(R Function(T) onSuccess, R Function(AppFailure) onFailure) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        Failure(:final failure) => onFailure(failure),
      };
}
```

This is an Either-style type: `Success` is the right/value side, `Failure` the left/error side. Because it is `sealed`, a `switch` that misses a branch is a compile error.
