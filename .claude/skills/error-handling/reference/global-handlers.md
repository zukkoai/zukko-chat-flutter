# Global error handling

Catch everything that escapes your `Result` flow — framework errors, async errors, and isolate errors — and forward to a reporter.

```dart
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Flutter framework errors (build/layout/paint)
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _reporter.recordError(details.exception, details.stack, fatal: false);
    };

    // Errors not caught by the Flutter framework (platform/async)
    PlatformDispatcher.instance.onError = (error, stack) {
      _reporter.recordError(error, stack, fatal: true);
      return true;
    };

    // Replace the red error screen in release
    ErrorWidget.builder = (details) => kReleaseMode
        ? const FriendlyErrorScreen()
        : ErrorWidget(details.exception);

    runApp(const ProviderScope(child: MyApp()));
  }, (error, stack) {
    // Uncaught zone errors
    _reporter.recordError(error, stack, fatal: true);
  });
}
```

## Crash reporting hook

Wire `_reporter` to Crashlytics or Sentry.

- **Crashlytics**: `FirebaseCrashlytics.instance.recordError(error, stack, fatal: ...)` and `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError`.
- **Sentry**: wrap `runApp` in `SentryFlutter.init` and use `Sentry.captureException`.

Add user/context breadcrumbs but never log PII or tokens.

## Rules
- Repositories/use cases return `Result<T>`; they do not throw across layers.
- `try/catch` only in data sources to produce `Failure`.
- UI pattern-matches `Result` and `AppFailure` exhaustively.
- One global guard (`runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError`) feeds the crash reporter.
