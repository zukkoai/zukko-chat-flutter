# Federated plugins — structure & endorsement

A federated plugin splits one logical plugin across several packages so platform teams can ship independently and third parties can add platform support.

## Package layout
```
my_plugin/                     # app-facing package — what users depend on
my_plugin_platform_interface/  # shared abstract interface + method-channel default
my_plugin_android/             # Android implementation
my_plugin_ios/                 # iOS implementation
my_plugin_web/                 # web implementation
```
Usually a pub workspace (see `pub-workspaces.md`) so all five resolve together.

## Platform interface package
Defines the abstract contract every platform implements:
```dart
// my_plugin_platform_interface
abstract class MyPluginPlatform extends PlatformInterface {
  MyPluginPlatform() : super(token: _token);
  static final Object _token = Object();

  static MyPluginPlatform _instance = MethodChannelMyPlugin();
  static MyPluginPlatform get instance => _instance;
  static set instance(MyPluginPlatform value) {
    PlatformInterface.verifyToken(value, _token);
    _instance = value;
  }

  Future<String?> getName() => throw UnimplementedError();
}
```
- Use `PlatformInterface` + a private token so external implementers must `extends`, not `implements`, the interface (prevents silent breakage when methods are added).

## A platform implementation pubspec
Each platform package registers itself and declares which interface it implements:
```yaml
# my_plugin_android/pubspec.yaml
flutter:
  plugin:
    implements: my_plugin            # the app-facing package it implements
    platforms:
      android:
        package: com.example.my_plugin
        pluginClass: MyPluginPlugin
        dartPluginClass: MyPluginAndroid   # the Dart class that registers instance
dependencies:
  my_plugin_platform_interface: ^1.0.0
```

## Endorsement — BOTH halves, or it's broken
The app-facing package endorses each platform package so users get it automatically. Endorsement requires **two** things in `my_plugin/pubspec.yaml`:
```yaml
# my_plugin/pubspec.yaml
dependencies:
  flutter: { sdk: flutter }
  my_plugin_platform_interface: ^1.0.0
  my_plugin_android: ^1.0.0          # (1) depend on the platform package
  my_plugin_ios: ^1.0.0

flutter:
  plugin:
    platforms:
      android:
        default_package: my_plugin_android   # (2) point the platform at it
      ios:
        default_package: my_plugin_ios
```
- **(1)** a dependency on the platform package **and** **(2)** `default_package:` for that platform. Plus the platform package's own `implements:` (above).
- **Half-done endorsement is a common mistake**: `implements:` alone, or the dependency without `default_package:` (or vice-versa), means the platform implementation isn't pulled in and calls hit `UnimplementedError` at runtime.

## Non-endorsed implementations
A third party can publish `my_plugin_windows` with `implements: my_plugin`; users add it as a direct dependency themselves. Endorsement just makes the *first-party* implementations automatic.

## Checklist
- Interface package uses `PlatformInterface` + token; methods throw `UnimplementedError` by default.
- Each platform package sets `implements:` + `dartPluginClass`/`pluginClass`.
- App-facing package: dependency **and** `default_package:` per endorsed platform.
- All packages versioned together (Melos `version`) so the interface and implementations stay compatible.
