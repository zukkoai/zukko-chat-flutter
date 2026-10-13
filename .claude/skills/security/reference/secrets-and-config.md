# Secrets vs config: --dart-define vs secure storage vs backend

The single most common security mistake is putting a real secret somewhere on the device. **Nothing shipped in the app binary is secret** — APKs/IPAs can be unzipped and `strings`-ed. Decide where each value belongs.

## Decision table

| Value | Where it goes | Why |
|---|---|---|
| Base URL, feature flags, build env | `--dart-define` / `--dart-define-from-file` | Non-secret config; fine to be extractable |
| Public/publishable keys (e.g. analytics) | `--dart-define` or asset | Designed to be public |
| User access/refresh tokens | `flutter_secure_storage` | Per-user, sensitive, must persist on device |
| API private keys, signing secrets, DB creds | **Backend only** | A server must hold these; the app calls the server |
| Third-party secret that signs requests | **Backend proxy** | Proxy the call server-side; never embed the secret |

Rule: **if leaking it would let an attacker impersonate your backend or another service, it must live on a server**, not in the app.

## --dart-define-from-file (config, not secrets)

```bash
# config/dev.json  (commit a template; gitignore real values if they reveal infra)
# { "API_BASE_URL": "https://dev.api.example.com", "ENABLE_BETA": true }
flutter run --dart-define-from-file=config/dev.json
```

```dart
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const enableBeta = bool.fromEnvironment('ENABLE_BETA');
```

- Values are **compiled into the binary and extractable** — obfuscation-grade only.
- Use it to avoid hardcoding env-specific config in source, not to hide secrets.
- `--dart-define-from-file` is the modern form; multiple `--dart-define=K=V` flags still work but are noisier.

## What --obfuscate does (and doesn't)

```bash
flutter build apk --obfuscate --split-debug-info=build/symbols
```

- Renames Dart symbols and removes some metadata → harder to read decompiled code.
- **Does NOT encrypt** strings, assets, or `--dart-define` values. They are still recoverable.
- Treat it as defense-in-depth for reverse-engineering effort, **never as secret storage**.

## Backend-held secrets pattern

When the app needs a third-party API that requires a secret:

1. App calls **your** backend (authenticated with the user's token).
2. Backend holds the third-party secret, calls the third party, returns the result.
3. The secret never reaches the device.

This also lets you rotate the secret without shipping an app update, and apply rate limits / abuse controls server-side.

## Checklist

- No private keys, signing secrets, or service credentials anywhere in the app (grep the repo + the built binary's strings).
- `--dart-define` used only for non-secret config.
- User tokens in `flutter_secure_storage`, short-lived, refreshed via the backend.
- Config files that reveal infra are gitignored; a `.example` template is committed.
