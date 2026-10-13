# Failure hierarchy

A sealed `AppFailure` lets the UI/logging branch on error category. Every failure carries a user-safe `message`.

```dart
sealed class AppFailure {
  const AppFailure(this.message);
  final String message;
}

final class ServerFailure extends AppFailure {
  const ServerFailure({required this.statusCode, required String message})
      : super(message);
  final int statusCode;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure(super.message);
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure(super.message);
}

final class CacheFailure extends AppFailure {
  const CacheFailure(super.message);
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});
  final Map<String, String> fieldErrors;
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message);
}
```

Keep the hierarchy small and category-based. `ValidationFailure.fieldErrors` lets the UI map server-side validation back to individual form fields.
