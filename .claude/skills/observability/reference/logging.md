# Structured logging — levels, redaction, kDebugMode

## Contents
- [1. Why not print](#1-why-not-print)
- [2. logging package setup](#2-logging-package-setup)
- [3. Levels](#3-levels)
- [4. Redaction (no PII / secrets)](#4-redaction-no-pii--secrets)
- [5. Bridge to crash reporter](#5-bridge-to-crash-reporter)

## 1. Why not print

`print()`/`debugPrint()` is unstructured, unlevelled, and **still runs in release** — flooding device logs and potentially leaking data. Use a structured logger and gate verbosity behind `kDebugMode`.

## 2. logging package setup

```bash
flutter pub add logging   # or: flutter pub add logger
```

```dart
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

void setupLogging() {
  Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING; // quiet in release
  Logger.root.onRecord.listen((r) {
    if (kDebugMode) {
      debugPrint('${r.level.name} ${r.loggerName}: ${r.message}');
    }
    if (r.level >= Level.WARNING) {
      reporter.log('${r.loggerName}: ${r.message}'); // breadcrumb to crash tool
    }
  });
}

final _log = Logger('checkout');
_log.info('started');           // dropped in release (level WARNING)
_log.warning('retrying payment'); // kept + breadcrumbed
```

## 3. Levels

| Level | Use for | Release |
|---|---|---|
| `FINE`/`FINER` | verbose tracing | dropped |
| `INFO` | lifecycle milestones | dropped (level WARNING) |
| `WARNING` | recoverable problems | kept + breadcrumb |
| `SEVERE` | errors worth a non-fatal | kept + `recordError` |

Set the root level from `kDebugMode` so verbose logs never ship.

## 4. Redaction (no PII / secrets)

Never log — and never breadcrumb — tokens, passwords, full emails/phones, auth headers, or raw request bodies. They leak into device logs, breadcrumbs, and crash context shipped to a vendor.

```dart
String redactEmail(String e) => e.replaceAllMapped(
    RegExp(r'(^.).*(@.*$)'), (m) => '${m[1]}***${m[2]}'); // a***@x.com

// Strip auth headers before logging a request:
final safe = Map.of(headers)..remove('Authorization')..remove('Cookie');
_log.fine('GET $url $safe');
```
For crash tools, apply the same redaction in `beforeSend` (Sentry) / before `crashlytics.log` (see `reference/sentry.md`, `reference/crashlytics.md`).

## 5. Bridge to crash reporter

Route `WARNING`+ records into the reporter as breadcrumbs and `SEVERE` into non-fatals:
```dart
if (r.level >= Level.SEVERE && r.error != null) {
  reporter.recordError(r.error, r.stackTrace, fatal: false);
}
```
This gives a readable breadcrumb trail leading up to each crash — without ever logging PII.
