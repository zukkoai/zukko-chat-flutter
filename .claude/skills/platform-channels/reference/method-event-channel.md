# Raw MethodChannel & EventChannel

Use these only when Pigeon isn't an option (one-off call, existing channel, third-party contract). For multi-method APIs prefer Pigeon.

## Contents
- [MethodChannel (request/response)](#methodchannel-requestresponse)
- [Full codec type mapping](#full-codec-type-mapping)
- [Error handling](#error-handling)
- [EventChannel (native → Dart streams)](#eventchannel-native--dart-streams)
- [Channel naming](#channel-naming)

## MethodChannel (request/response)
**Dart:**
```dart
const _channel = MethodChannel('com.example.app/battery');

Future<int> getBatteryLevel() async {
  final level = await _channel.invokeMethod<int>('getBatteryLevel');
  return level ?? -1;
}
```

**Android (Kotlin)** — `MainActivity` / plugin:
```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.app/battery")
  .setMethodCallHandler { call, result ->
    when (call.method) {
      "getBatteryLevel" -> result.success(readBattery()) // Int → Dart int
      else -> result.notImplemented()
    }
  }
```

**iOS (Swift)** — `AppDelegate`:
```swift
let channel = FlutterMethodChannel(name: "com.example.app/battery",
                                   binaryMessenger: controller.binaryMessenger)
channel.setMethodCallHandler { call, result in
  switch call.method {
  case "getBatteryLevel": result(self.readBattery())   // Int → Dart int
  default: result(FlutterMethodNotImplemented)
  }
}
```

## Full codec type mapping
`StandardMessageCodec` is the default. Get these wrong and you get a runtime cast error.

| Dart | Android (Kotlin/Java) | iOS (Swift/ObjC) |
|---|---|---|
| `null` | `null` | `nil` / `NSNull` |
| `bool` | `Boolean` | `NSNumber(bool)` |
| `int` (≤32-bit) | `Integer` | `NSNumber(int)` |
| `int` (>32-bit) | `Long` | `NSNumber(long)` |
| `double` | `Double` | `NSNumber(double)` |
| `String` | `String` | `String` / `NSString` |
| `Uint8List` | `byte[]` | `FlutterStandardTypedData(bytes:)` |
| `Int32List` | `int[]` | `FlutterStandardTypedData(int32:)` |
| `Float64List` | `double[]` | `FlutterStandardTypedData(float64:)` |
| `List` | `List<Object?>` | `[Any?]` |
| `Map` | `Map<Object?, Object?>` | `[AnyHashable: Any?]` |

Key trap: a Dart `int` can arrive as `Integer` **or** `Long` on Android depending on magnitude. Read it as the wider type (`Number`/`Long`) or convert, rather than `as Int`.

## Error handling
On the native side, signal errors with the platform error API so Dart gets a `PlatformException`:
```kotlin
result.error("UNAVAILABLE", "Battery info unavailable", null)
```
```dart
try {
  await getBatteryLevel();
} on PlatformException catch (e) {
  // e.code == "UNAVAILABLE"
}
```
Call `result.success`/`result.error`/`notImplemented` **exactly once**. Never calling it hangs the Dart `Future`; calling twice crashes.

## EventChannel (native → Dart streams)
For continuous events (sensors, location, connectivity). Native side keeps a sink and pushes; Dart subscribes.

**Dart:**
```dart
const _events = EventChannel('com.example.app/accelerometer');
Stream<List<double>> get accelStream =>
    _events.receiveBroadcastStream().map((e) => (e as List).cast<double>());
```

**Android (Kotlin):**
```kotlin
EventChannel(messenger, "com.example.app/accelerometer").setStreamHandler(
  object : EventChannel.StreamHandler {
    var listener: SensorEventListener? = null
    override fun onListen(args: Any?, sink: EventChannel.EventSink) {
      listener = registerSensor { values -> sink.success(values) }
    }
    override fun onCancel(args: Any?) { unregisterSensor(listener) } // ❗ free resources
  })
```
**iOS** mirrors this with `FlutterStreamHandler` (`onListen`/`onCancel`).

Always implement `onCancel` to stop the native source — otherwise you leak sensors/listeners when Dart cancels the subscription.

## Channel naming
Use a unique, namespaced channel name (`com.yourcompany.app/feature`). Two channels with the same name collide. Keep the same string in Dart and native exactly.
