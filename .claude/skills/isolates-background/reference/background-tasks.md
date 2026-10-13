# OS background tasks (workmanager / background_fetch)

## Contents
- [What this is and isn't](#what-this-is-and-isnt)
- [Add the package](#add-the-package)
- [The callback dispatcher — vm:entry-point](#the-callback-dispatcher--vmentry-point)
- [Registering tasks](#registering-tasks)
- [Android native setup](#android-native-setup)
- [iOS native setup](#ios-native-setup)
- [OS limits and footguns](#os-limits-and-footguns)

## What this is and isn't
OS background execution runs Dart code **when your app is backgrounded or terminated** — driven by the OS scheduler, not your running UI. This is a *third concern*, separate from isolates and async. Use it for: periodic sync, deferred uploads, cache refresh.

It is **not** for keeping the UI responsive (that's isolates) and **not** guaranteed real-time (the OS decides when, within constraints).

## Add the package
```bash
flutter pub add workmanager
```
`workmanager` wraps Android WorkManager and iOS BGTaskScheduler/background-fetch. `background_fetch` is an alternative with a simpler periodic model. Both are version-sensitive — check `pub.dev/packages/workmanager/changelog` (the API changed notably across 0.5 → 0.6+; older tutorials use stale call shapes).

## The callback dispatcher — vm:entry-point
The entry point the OS calls **must** be a **top-level or static** function annotated `@pragma('vm:entry-point')`. Without the annotation it compiles and runs in debug but is **tree-shaken out of release builds**, so the task silently never fires.

```dart
@pragma('vm:entry-point')        // ❗ REQUIRED — release tree-shakes it otherwise
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized(); // bindings for this fresh isolate
    switch (task) {
      case 'syncTask':
        await _doSync();
        return true; // success; return false to let WorkManager retry
      default:
        return true;
    }
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(const MyApp());
}
```

## Registering tasks
```dart
// One-off
Workmanager().registerOneOffTask('upload-1', 'syncTask',
    constraints: Constraints(networkType: NetworkType.connected));

// Periodic (Android: min 15 min interval)
Workmanager().registerPeriodicTask('sync-periodic', 'syncTask',
    frequency: const Duration(hours: 1));
```

## Android native setup
WorkManager is registered by the plugin, but for full control verify:
- **Permissions** in `android/app/src/main/AndroidManifest.xml` as needed (e.g. `INTERNET`; on Android 13+ `POST_NOTIFICATIONS` if the task posts notifications).
- If you customize the WorkManager initializer, ensure the default `androidx.work.WorkManagerInitializer` provider isn't removed unless you re-provide one.
- Battery optimizations / Doze can delay tasks; periodic minimum is **15 minutes**.

## iOS native setup
iOS is stricter. In Xcode / `ios/Runner`:
1. **Enable Background Modes** capability → check **Background fetch** and **Background processing**.
2. Add task identifiers to `ios/Runner/Info.plist`:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>com.yourapp.sync</string>
</array>
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
```
3. In `ios/Runner/AppDelegate.swift`, register the identifier per the package's iOS setup docs (the plugin provides the registration call).

iOS does **not** guarantee timing and will throttle apps that overrun their budget or that the user rarely opens.

## OS limits and footguns
- **Periodic minimum 15 min** (Android); iOS schedules at the OS's discretion — could be hours.
- **No exact timing** — never promise "every minute." For exact alarms use platform alarm APIs, not background fetch.
- **Tasks are killed if over budget** (CPU/time) — keep work short; chunk large jobs.
- **Release-only failures:** missing `@pragma('vm:entry-point')` is the #1 cause of "works in debug, dead in release."
- **No isolates on web**, and no OS background execution model like mobile — don't target web with these packages.
- Test on a **real device**, not just an emulator, and in **release/profile** to catch tree-shaking issues.
