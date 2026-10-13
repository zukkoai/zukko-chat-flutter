# Environment config: --dart-define-from-file + appFlavor

Two separate concerns:
- **Which flavor is running** → read the built-in **`appFlavor`** constant.
- **Per-environment values** (base URL, analytics key, feature flags) → inject with **`--dart-define-from-file`**.

## appFlavor (Flutter 3.19+)

When you build with `--flavor dev`, Flutter sets `appFlavor` automatically. No `--dart-define` needed.

```dart
import 'package:flutter/foundation.dart' show appFlavor;

enum Env { dev, stg, prod }

Env get currentEnv => switch (appFlavor) {
      'dev' => Env.dev,
      'stg' => Env.stg,
      _ => Env.prod,
    };
```

**Do not** use `String.fromEnvironment('FLAVOR')` — that only works if you manually pass `--dart-define=FLAVOR=dev`, which `appFlavor` makes obsolete.

## Config JSON (one file per environment)

```jsonc
// config/dev.json
{
  "API_BASE_URL": "https://api.dev.acme.com",
  "SENTRY_DSN": "",
  "ENABLE_LOGGING": true
}
```

```jsonc
// config/prod.json
{
  "API_BASE_URL": "https://api.acme.com",
  "SENTRY_DSN": "https://...@sentry.io/123",
  "ENABLE_LOGGING": false
}
```

Read with the typed `String.fromEnvironment` / `bool.fromEnvironment` (these *are* correct for config keys — only the `FLAVOR` hack is wrong):

```dart
class AppConfig {
  static const apiBaseUrl   = String.fromEnvironment('API_BASE_URL');
  static const enableLogging = bool.fromEnvironment('ENABLE_LOGGING');
}
```

`fromEnvironment` must be `const` and the key must match the JSON exactly.

## Running / building

```bash
flutter run   --flavor dev  -t lib/main_dev.dart  --dart-define-from-file=config/dev.json
flutter build appbundle --flavor prod -t lib/main_prod.dart --dart-define-from-file=config/prod.json
```

Multiple files: pass `--dart-define-from-file` more than once; later files override earlier keys.

## Security boundary

- `--dart-define` values are **baked into the binary**, Dart-side only (not visible to native Swift/Kotlin), and **extractable** by reverse-engineering — obfuscation, not encryption.
- Fine for **non-secret** config (URLs, flags, public IDs).
- **Never** put API secrets, signing keys, or private tokens here, and don't commit a `config/*.json` that contains them. For real secrets see the `security` skill (native keychain / backend-issued tokens).

## IDE launch configs

`.vscode/launch.json` — one entry per flavor so teammates run them identically:

```jsonc
{
  "configurations": [
    { "name": "dev",  "request": "launch", "type": "dart",
      "program": "lib/main_dev.dart",
      "args": ["--flavor", "dev", "--dart-define-from-file", "config/dev.json"] }
  ]
}
```
