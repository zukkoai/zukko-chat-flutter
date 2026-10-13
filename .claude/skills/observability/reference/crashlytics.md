# Firebase Crashlytics — setup + symbol upload

## Contents
- [1. Install](#1-install)
- [2. Native config](#2-native-config)
- [3. Wire into error capture](#3-wire-into-error-capture)
- [4. Symbol upload (the release footgun)](#4-symbol-upload-the-release-footgun)
- [5. Verify](#5-verify)

Crashlytics requires Firebase configured — see `firebase`.

## 1. Install

```bash
flutter pub add firebase_crashlytics
```
Version-sensitive — read `pub.dev/packages/firebase_crashlytics/changelog`.

## 2. Native config

- **Android** `android/app/build.gradle.kts`: apply the Crashlytics Gradle plugin (`com.google.firebase.crashlytics`) and ensure the google-services plugin is applied; declare the plugin in `android/settings.gradle.kts`/root build file.
- **iOS**: the Firebase pods come via `flutterfire`/CocoaPods. For symbol upload, the build must produce dSYMs (default for Release archives).

## 3. Wire into error capture

```dart
final crashlytics = FirebaseCrashlytics.instance;

FlutterError.onError = crashlytics.recordFlutterFatalError; // framework
PlatformDispatcher.instance.onError = (e, s) {
  crashlytics.recordError(e, s, fatal: true);
  return true;
};
```
- Non-fatals: `crashlytics.recordError(e, s, fatal: false)`.
- Context: `crashlytics.setUserIdentifier(opaqueId)`, `crashlytics.setCustomKey('screen', name)`, `crashlytics.log('breadcrumb')` — all PII-free.
- Disable collection in debug if noisy: `await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);`.

## 4. Symbol upload (the release footgun)

Release builds with `--obfuscate --split-debug-info=build/symbols` (see `release`) produce **unreadable** stack traces until symbols are uploaded.

```bash
# Dart obfuscation symbols (from --split-debug-info):
firebase crashlytics:symbols:upload --app=<firebase-app-id> build/symbols
```
- **iOS dSYMs** upload separately — the Crashlytics build phase / `upload-symbols` script handles them; for App Store builds, dSYMs may come from App Store Connect (enable bitcode-off dSYM download or upload from the archive).
- Upload **per release** with the **matching** symbol set — symbols from a different build won't symbolicate.
- Automate this in CI right after the build step (cross-ref `ci-cd`); a forgotten manual upload is the usual cause of hex-only crash reports.

## 5. Verify

- [ ] Force a test crash: `FirebaseCrashlytics.instance.crash();` in a debug button → appears in console after relaunch.
- [ ] `FlutterError.onError` and `PlatformDispatcher.onError` both routed to Crashlytics.
- [ ] CI uploads Dart symbols (`crashlytics:symbols:upload`) and iOS dSYMs every release.
- [ ] No PII in `setUserIdentifier`/custom keys/logs.
