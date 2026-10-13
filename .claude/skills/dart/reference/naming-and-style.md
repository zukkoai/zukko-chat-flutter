# Naming & style — full examples

## Null safety

Prefer null-aware operators over force-unwrap. Reserve `!` for cases you can prove non-null.

```dart
// Avoid: throws if null, crashes at runtime
final name = user!.profile!.displayName;

// Prefer: null-aware access, defaults, assignment
final name = user?.profile?.displayName ?? 'Anonymous';
cache ??= computeDefault();
items?.forEach(print); // null-aware call
```

## Intention-revealing names

```dart
// Avoid
final d = DateTime.now().difference(start).inDays;
if (d > 30) flag = true;

// Prefer
final daysSinceStart = DateTime.now().difference(start).inDays;
final isExpired = daysSinceStart > 30;
```

- No abbreviations: `database`, `repository`, `configuration` — not `db`, `repo`, `cfg`.
- Acronyms longer than two letters become words: `HttpClient`, `userId`, `parseJsonResponse` — not `HTTPClient`, `userID`.
- Booleans read as predicates: `isVisible`, `hasItems`, `canSubmit`, `shouldRetry`.

## Expression bodies

Prefer `=>` for single-expression functions and getters; getters must be cheap and side-effect-free.

```dart
// Avoid
int area() {
  return width * height;
}

// Prefer
int get area => width * height;
double scaled(double factor) => area * factor;
```

## Collection literals, spread, collection-if/for

Build collections declaratively rather than mutating imperatively.

```dart
// Avoid
final list = <Widget>[];
list.add(header);
if (showBody) list.add(body);

// Prefer
final list = <Widget>[
  header,
  if (showBody) body,
  for (final item in items) Tile(item),
  ...extraWidgets,
  ...?nullableWidgets, // null-aware spread
];
```

## Extension methods

Add behavior to existing types without subclassing. Keep extensions focused and named.

```dart
extension StringX on String {
  bool get isBlank => trim().isEmpty;
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
```

## Documentation comments

Use `///` doc comments on public APIs. Start with a one-sentence summary; reference parameters with `[brackets]`.

```dart
/// Fetches the user with [id], or `null` if not found.
///
/// Throws [NetworkException] if the request fails.
Future<User?> fetchUser(String id) async { /* ... */ }
```

- Avoid redundant comments that merely restate the code.
- Avoid `print()` in production — use a logger.

## Single Responsibility & function extraction (worked)

```dart
// Avoid: one method parses, validates, persists, and logs
Future<void> handle(String raw) async {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  if (json['id'] == null) throw ArgumentError('missing id');
  await db.insert(json);
  print('saved ${json['id']}');
}

// Prefer: one job each; shared logic extracted and named
Future<void> handle(String raw) async {
  final user = _parse(raw);
  _validate(user);
  await _save(user);
}

User _parse(String raw) =>
    User.fromJson(jsonDecode(raw) as Map<String, dynamic>);

void _validate(User user) {
  if (user.id.isEmpty) throw ArgumentError('missing id');
}

Future<void> _save(User user) async {
  await db.insert(user.toJson());
  log.info('saved ${user.id}');
}
```

Extract the moment you copy-paste a block: give the shared logic a name and call it from both sites.
