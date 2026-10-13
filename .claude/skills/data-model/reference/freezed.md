# freezed 3.x + json_serializable

Use for data classes where generated equality, `copyWith`, and JSON pay for the codegen cost.

## Data class

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String name,
    String? email,            // nullable optional field
    @Default(false) bool isAdmin,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

- In freezed 3, a single-variant data class is declared `abstract class`; a multi-variant union is `sealed class` (see below). The old plain `@freezed class X with _$X` form is gone.
- Generated `copyWith` distinguishes "absent" from "explicit null", so it **can** clear a nullable field — unlike hand-written `x ?? this.x`.

## Union / variant types

freezed union (sealed-class style):

```dart
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(User user) = Authenticated;
  const factory AuthState.unauthenticated() = Unauthenticated;
}

String describe(AuthState s) => switch (s) {
  AuthLoading() => 'loading',
  Authenticated(:final user) => 'as ${user.name}',
  Unauthenticated() => 'logged out',
};
```

The generated `map`/`when` (and `maybeMap`/`whenOrNull`) helpers are **deprecated** in freezed 3 — use Dart 3 `switch`/pattern matching over the sealed subclasses, as above.

## Running the generator

```bash
dart run build_runner build --delete-conflicting-outputs
# or, while iterating:
dart run build_runner watch --delete-conflicting-outputs
```

## pubspec.yaml

```yaml
dependencies:
  freezed_annotation: ^3.0.0
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^3.2.5
  json_serializable: ^6.8.0
```

Dependencies: `freezed_annotation` + `json_annotation`. Dev dependencies: `build_runner`, `freezed`, `json_serializable`.
