# Hand-written immutable models

## Immutable class with copyWith, JSON, equality

```dart
class User {
  const User({required this.id, required this.name, this.email});

  final String id;
  final String name;
  final String? email; // nullable = optional

  User copyWith({String? name, String? email}) =>
      User(id: id, name: name ?? this.name, email: email ?? this.email);

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.name == name &&
      other.email == email;

  @override
  int get hashCode => Object.hash(id, name, email);
}
```

Use `const` constructors and `final` fields. Note: `copyWith` with `param ?? this.param` cannot set a value back to `null` — if that matters, switch to freezed or a sentinel.

## Sealed union (Dart 3)

For closed sets of states, sealed classes give exhaustive switching with no codegen.

```dart
sealed class RemoteData<T> {
  const RemoteData();
}

final class Loading<T> extends RemoteData<T> {
  const Loading();
}

final class Data<T> extends RemoteData<T> {
  const Data(this.value);
  final T value;
}

final class Failure<T> extends RemoteData<T> {
  const Failure(this.error);
  final Object error;
}

String describe(RemoteData<int> state) => switch (state) {
  Loading() => 'loading',
  Data(:final value) => 'value: $value',
  Failure(:final error) => 'error: $error',
};
```

## Enhanced enums

Prefer enhanced enums (with fields/methods) over loose constants. Switching over an enum is exhaustive — handle every case without a `default`.

```dart
enum Currency {
  usd('USD', r'$'),
  eur('EUR', '€'),
  gbp('GBP', '£');

  const Currency(this.code, this.symbol);
  final String code;
  final String symbol;

  static Currency fromCode(String code) =>
      values.firstWhere((c) => c.code == code);
}
```
