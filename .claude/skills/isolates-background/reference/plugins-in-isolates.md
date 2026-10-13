# Calling plugins from a spawned isolate

## The problem
Plugins talk to native code over a **binary messenger** that is bound to the **root (UI) isolate**. A freshly spawned isolate (`Isolate.run`, `compute`, a workmanager callback, an `Isolate.spawn` worker) has **no messenger**, so any plugin call (`SharedPreferences`, `path_provider`, `sqflite`, etc.) throws something like:

```
ServicesBinding.defaultBinaryMessenger was accessed before the binding was initialized.
```

## The fix: BackgroundIsolateBinaryMessenger
Capture a `RootIsolateToken` on the UI isolate, pass it into the new isolate, and initialize the messenger there before any plugin call.

```dart
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<String> readDocsPathInIsolate() {
  final token = RootIsolateToken.instance!;        // 1. capture on UI isolate
  return Isolate.run(() async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token); // 2. init in isolate
    final dir = await getApplicationDocumentsDirectory();      // 3. plugin now works
    return dir.path;
  });
}
```

Key points:
- `RootIsolateToken.instance` is **only non-null on the root isolate** — read it *before* spawning, then pass it in.
- Call `BackgroundIsolateBinaryMessenger.ensureInitialized(token)` **once, first thing** in the new isolate, before touching any plugin.
- The token is sendable, so it can cross the boundary safely.

## With workmanager / background_fetch callbacks
The same applies inside a background callback. You usually can't read `RootIsolateToken.instance` there (it's a brand-new isolate with no root), so either:
- avoid plugins that need the messenger, or
- use plugin APIs designed for background isolates, or
- for plugins that support it, follow their documented background-init path.

Most well-behaved plugins (e.g. `shared_preferences`, `path_provider`) work in a workmanager callback **as long as** you don't need a token (the background entry point bootstraps its own binding via `WidgetsFlutterBinding.ensureInitialized()`):

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized(); // bootstraps bindings for this isolate
    final prefs = await SharedPreferences.getInstance();
    // ...
    return true;
  });
}
```

## Checklist
- [ ] `RootIsolateToken.instance!` read on the UI isolate, passed into the spawned isolate.
- [ ] `BackgroundIsolateBinaryMessenger.ensureInitialized(token)` is the **first** line in the spawned isolate.
- [ ] No `BuildContext`, `ref`, or live DB handle captured by the isolate closure.
- [ ] For workmanager callbacks: `WidgetsFlutterBinding.ensureInitialized()` and `@pragma('vm:entry-point')` present.
