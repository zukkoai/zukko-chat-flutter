# Declarations — var / final / const / late / required

## Decision order

1. **`const`** — value is known at compile time (canonicalized, zero runtime allocation).
2. **`final`** — set once at runtime; the default for fields and locals.
3. **`late final`** — deferred init that needs `this`/other fields or is expensive and lazy.
4. **`var`** — only when the binding is actually reassigned.

Never use `dynamic` to dodge a type.

## final is the default

```dart
// Avoid: var implies "this will change" — it won't
var userId = fetchId();

// Prefer
final userId = fetchId();

// var is correct only when you reassign
var attempts = 0;
while (!done) { attempts++; }
```

## const for compile-time constants

```dart
const maxRetries = 3;
const padding = EdgeInsets.all(8);
const config = AppConfig(retries: 3); // const constructor

class AppConfig {
  const AppConfig({required this.retries});
  final int retries;
}
```

Use `const` everywhere it is legal; identical const instances are shared.

## late final vs bare late

```dart
// Avoid: bare late + nullable backing field to silence the analyzer
String? _config;
String get config => _config!;

// Prefer: late final, initialized exactly once before first read
late final String config;

// late final with field-dependent initializer (can't go in the ctor list)
class Repo {
  Repo(this._client);
  final HttpClient _client;
  late final UserApi _users = UserApi(_client); // built on first access
}
```

- Reading a `late` field before assignment throws `LateInitializationError`.
- Avoid `late` for async-set fields — there is no guarantee it is set before read.

## required named params (Flutter-style)

```dart
class Button {
  const Button({
    required this.label,   // mandatory — fails fast at construction
    this.onTap,            // truly optional
    this.enabled = true,   // optional with default
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;
}
```

- Mark every mandatory named param `required`.
- Make a param nullable only when `null` is a genuine, valid value.

## Pitfall: copyWith can't set a field back to null

```dart
class User {
  const User({required this.id, this.email});
  final String id;
  final String? email;

  // BUG: email: null falls through to this.email — can't clear it
  User copyWith({String? email}) => User(id: id, email: email ?? this.email);
}
```

If clearing a field to `null` matters:
- Use **freezed** (its `copyWith` distinguishes "absent" from "null"), or
- Use a sentinel:

```dart
const _unset = Object();

User copyWith({Object? email = _unset}) => User(
      id: id,
      email: identical(email, _unset) ? this.email : email as String?,
    );
```
