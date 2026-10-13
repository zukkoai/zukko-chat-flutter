# Sentry — setup + symbols + tracing

## Contents
- [1. Install + init](#1-install--init)
- [2. Error capture](#2-error-capture)
- [3. Symbols / dSYM upload (release footgun)](#3-symbols--dsym-upload-release-footgun)
- [4. Tracing / performance](#4-tracing--performance)
- [5. Verify](#5-verify)

## 1. Install + init

```bash
flutter pub add sentry_flutter
```
Version-sensitive — read `pub.dev/packages/sentry_flutter/changelog`.

`SentryFlutter.init` wraps `runApp` and **auto-hooks `FlutterError.onError` and the zone for you** — you generally don't hand-wire those when using Sentry:
```dart
Future<void> main() async {
  await SentryFlutter.init(
    (o) {
      o.dsn = const String.fromEnvironment('SENTRY_DSN'); // pass via --dart-define, not hardcoded
      o.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
      o.environment = kReleaseMode ? 'prod' : 'dev';
      o.beforeSend = (event, hint) => redact(event); // strip PII (see logging.md)
    },
    appRunner: () => runApp(const MyApp()),
  );
}
```
Keep the **DSN out of source** — inject via `--dart-define`/CI secret (cross-ref `ci-cd`).

## 2. Error capture

- Handled errors: `await Sentry.captureException(e, stackTrace: s);`
- Messages: `await Sentry.captureMessage('...');`
- Context: `Sentry.configureScope((s) => s.setUser(SentryUser(id: opaqueId)));` — **id only, no email/PII**.
- Breadcrumbs: `Sentry.addBreadcrumb(Breadcrumb(message: '...'));` — PII-free.

## 3. Symbols / dSYM upload (release footgun)

Obfuscated release builds (`--obfuscate --split-debug-info=build/symbols`) need symbols uploaded or events are unreadable:
- Use the **Sentry Dart plugin** (Gradle/build integration) or `sentry-cli` to upload **Dart debug symbols** from `build/symbols`.
- Upload the **iOS dSYM** as well (`sentry-cli debug-files upload`).
- A `--dart-define=SENTRY_AUTO_UPLOAD=...` / `sentry.properties` with the auth token drives automated upload — keep the **auth token in CI secrets**, never committed.
- Upload per release with the matching build — mismatched symbols won't resolve frames.

## 4. Tracing / performance

```dart
final tx = Sentry.startTransaction('checkout', 'task');
try { await doWork(); } finally { await tx.finish(); }
```
- `tracesSampleRate` controls performance sampling — keep it **low in prod** (e.g. 0.1–0.2) to control cost/volume; 1.0 only in dev.
- `SentryNavigatorObserver` auto-instruments screen transitions (cross-ref `navigation`).

## 5. Verify

- [ ] DSN injected via `--dart-define`/secret, not hardcoded.
- [ ] `beforeSend` redacts PII/tokens.
- [ ] CI uploads Dart symbols + iOS dSYM each release; auth token is a secret.
- [ ] `tracesSampleRate` sane for prod.
- [ ] Test event (`captureMessage`) lands in the Sentry project.
