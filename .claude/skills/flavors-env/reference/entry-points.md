# Entry points: per-flavor main files vs single entry

Two valid strategies. Pick one and stay consistent.

## A. Separate entry points (`main_dev.dart`, `main_prod.dart`)

Best when flavors differ in *setup* (different Firebase init, error reporting, DI overrides). Each entry runs a shared `bootstrap`, then `runApp`.

```dart
// lib/bootstrap.dart  — shared setup, flavor passed in
Future<void> bootstrap(Env env) async {
  WidgetsFlutterBinding.ensureInitialized();
  // env-specific init: analytics, crash reporting, DI
  runApp(MyApp(env: env));
}
```

```dart
// lib/main_dev.dart
import 'bootstrap.dart';
void main() => bootstrap(Env.dev);
```

```dart
// lib/main_prod.dart
import 'bootstrap.dart';
void main() => bootstrap(Env.prod);
```

Run: `flutter run --flavor dev -t lib/main_dev.dart`.

- **Pro**: each flavor's init is explicit and tree-shakeable.
- **Con**: N near-identical `main_*.dart` files to keep in sync — keep them one-liners.

## B. Single entry reading the flavor

Best when flavors differ only in *config values*, not setup. One `main.dart` reads `appFlavor`.

```dart
// lib/main.dart
import 'package:flutter/foundation.dart' show appFlavor;

void main() {
  final env = switch (appFlavor) {
    'dev' => Env.dev,
    'stg' => Env.stg,
    _ => Env.prod,
  };
  bootstrap(env);
}
```

Run: `flutter run --flavor dev` (no `-t` needed — default `lib/main.dart`).

- **Pro**: one entry point, no duplication.
- **Con**: all flavor setup paths compile into every build (minor).

## Which to choose

| Need | Strategy |
|------|----------|
| Different Firebase project / crash-reporting per flavor | A (separate entries) |
| Same setup, only URLs/flags differ | B (single entry + `appFlavor`) |
| CI scripts already pass `-t lib/main_<flavor>.dart` | A (match existing) |

## Don't

- Don't read `appFlavor` *and* duplicate entry files — that's two sources of truth. Use exactly one.
- Don't `runApp` before `bootstrap` finishes async init (Firebase, prefs) — `await` it.
