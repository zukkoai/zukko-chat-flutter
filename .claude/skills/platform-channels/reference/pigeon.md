# Pigeon — type-safe platform channels

## Contents
- [Why Pigeon over raw MethodChannel](#why-pigeon-over-raw-methodchannel)
- [Add Pigeon](#add-pigeon)
- [Define the API (pigeons/messages.dart)](#define-the-api-pigeonsmessagesdart)
- [Generate](#generate)
- [Implement the host side](#implement-the-host-side)
- [Call from Dart](#call-from-dart)
- [FlutterApi: native → Dart calls](#flutterapi-native--dart-calls)
- [Federated plugin structure](#federated-plugin-structure)

## Why Pigeon over raw MethodChannel
Hand-written channels are stringly-typed: method names and argument keys are strings, types are `dynamic`, and nothing is checked until runtime. Pigeon takes one Dart file describing your API and **generates** matching Dart + Kotlin/Swift code with real types, correct codec mappings, and async signatures. You implement an interface; the wiring is generated. This is the recommended approach for any non-trivial native API.

## Add Pigeon
```bash
flutter pub add --dev pigeon
```
Version-sensitive (config options and generated style evolve) — check `pub.dev/packages/pigeon/changelog`.

## Define the API (pigeons/messages.dart)
A pure-definition file — no implementations, never imported by app code.

```dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  kotlinOut: 'android/app/src/main/kotlin/com/example/app/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.example.app'),
  swiftOut: 'ios/Runner/Messages.g.swift',
))

class User {
  User(this.id, this.name);
  final int id;
  final String name;
}

@HostApi()           // Dart calls native
abstract class UserApi {
  @async
  User getUser(int id);
  void saveUser(User user);
}
```

## Generate
```bash
dart run pigeon --input pigeons/messages.dart
```
(Or rely on `@ConfigurePigeon` and run `dart run pigeon` per its docs.) Re-run whenever the definition changes; commit the generated files.

## Implement the host side
**Android (Kotlin):** implement the generated `UserApi` interface and register it.
```kotlin
class UserApiImpl : UserApi {
  override fun getUser(id: Long, callback: (Result<User>) -> Unit) {
    callback(Result.success(User(id, "Ada")))
  }
  override fun saveUser(user: User) { /* ... */ }
}
// in onAttachedToEngine / MainActivity:
UserApi.setUp(flutterEngine.dartExecutor.binaryMessenger, UserApiImpl())
```

**iOS (Swift):** conform to the generated protocol and register similarly via `UserApiSetup.setUp(binaryMessenger:api:)`.

## Call from Dart
```dart
import 'src/messages.g.dart';

final api = UserApi();
final user = await api.getUser(42); // typed, no string keys, no manual casts
```

## FlutterApi: native → Dart calls
For native→Dart calls (e.g. native pushes data), use `@FlutterApi()`:
```dart
@FlutterApi()
abstract class AppCallbacks {
  void onTokenRefreshed(String token);
}
```
Generated Dart you implement; native side gets a generated proxy to call it.

## Federated plugin structure
When authoring a reusable plugin (not just app-local interop), use the **federated** layout:
- `my_plugin` — app-facing package (the API surface).
- `my_plugin_platform_interface` — abstract platform interface + `MethodChannel` default.
- `my_plugin_android`, `my_plugin_ios`, ... — per-platform implementations registering with the interface.

Pigeon-generated APIs live in the platform implementations; the interface package defines the abstract contract. See the `packaging` skill for `pubspec` plugin declarations and `dartPluginClass` registration.
