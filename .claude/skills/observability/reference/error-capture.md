# Error capture — every source, full main() wiring

## Contents
- [1. The three error channels](#1-the-three-error-channels)
- [2. Full main() (vendor-agnostic)](#2-full-main-vendor-agnostic)
- [3. Why not runZonedGuarded](#3-why-not-runzonedguarded)
- [4. Non-fatals, user id, breadcrumbs](#4-non-fatals-user-id-breadcrumbs)

## 1. The three error channels

Flutter routes errors through separate paths. Capturing one is not enough.

| Channel | Catches | Wire with |
|---|---|---|
| `FlutterError.onError` | Framework errors: build, layout, paint, gesture | assign a handler |
| `PlatformDispatcher.instance.onError` | Async + otherwise-uncaught Dart errors | return `true` (handled) |
| `Isolate.current.addErrorListener` | Errors in **other isolates** (compute/workers) | a `RawReceivePort` listener |

## 2. Full main() (vendor-agnostic)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await reporter.init(); // Crashlytics.instance / Sentry — see their reference

  // 1. Framework errors.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // keep red screen in debug
    reporter.recordFlutterError(details, fatal: true);
  };

  // 2. Async / uncaught — modern global catch-all.
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.recordError(error, stack, fatal: true);
    return true; // mark handled so it isn't re-thrown
  };

  // 3. Background isolate errors.
  Isolate.current.addErrorListener(RawReceivePort((pair) {
    final List<dynamic> errorAndStack = pair;
    reporter.recordError(
      errorAndStack.first,
      errorAndStack.last == null ? null : StackTrace.fromString('${errorAndStack.last}'),
      fatal: true,
    );
  }).sendPort);

  runApp(const MyApp());
}
```

`reporter` here abstracts the vendor: `recordFlutterError`/`recordError` map to `FirebaseCrashlytics.instance.recordFlutterFatalError` / `recordError` or `Sentry.captureException`.

## 3. Why not runZonedGuarded

Historically you wrapped `runApp` in `runZonedGuarded` to catch async errors. As of modern Flutter, **`PlatformDispatcher.instance.onError` catches those same async/uncaught errors** with less overhead and no zone gymnastics. Prefer it. Reserve `runZonedGuarded` for narrow cases (e.g. capturing errors from a specific zone, or older SDKs). Don't set both as your primary global path — you'll double-report.

## 4. Non-fatals, user id, breadcrumbs

```dart
try {
  await risky();
} catch (e, s) {
  reporter.recordError(e, s, fatal: false); // handled → non-fatal
}

reporter.setUserId(account.opaqueId); // a non-PII opaque id, NOT email/phone
reporter.log('checkout: started'); // breadcrumb — no tokens/PII
```
- **Non-fatals** keep the app running but surface in the dashboard — use for caught-but-notable failures.
- **User id**: an opaque, non-reversible id only. Never set email/phone/name.
- **Breadcrumbs/log**: short, structured, PII-free (see `reference/logging.md`).
