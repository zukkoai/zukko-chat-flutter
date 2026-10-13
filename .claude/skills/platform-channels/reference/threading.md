# Threading & ANR avoidance for native interop

## The rule
`MethodChannel`/`EventChannel`/Pigeon handlers run on the **platform main thread** (Android UI thread / iOS main queue). Any heavy work there blocks rendering and triggers an **ANR** ("Application Not Responding") on Android after ~5s, or a frozen UI on iOS. Move heavy work off that thread and reply back on it.

## Android — BinaryMessenger TaskQueue
Run the channel's handler on a background task queue so heavy work never touches the UI thread.

```kotlin
val messenger = flutterEngine.dartExecutor.binaryMessenger
val taskQueue = messenger.makeBackgroundTaskQueue()   // background serial queue

MethodChannel(messenger, "com.example.app/work", StandardMethodCodec.INSTANCE, taskQueue)
  .setMethodCallHandler { call, result ->
    when (call.method) {
      "heavy" -> {
        val out = doHeavyWork(call.arguments)   // already off the UI thread
        result.success(out)                     // safe to reply from the task queue
      }
      else -> result.notImplemented()
    }
  }
```
- `makeBackgroundTaskQueue()` gives a serial background queue; pass it as the channel's `taskQueue`.
- If you instead use your own executor, **post `result.success/error` back appropriately** — the Flutter result API is safe to call from any thread on recent engines, but never call it twice and never never call it.

## iOS — hop to a background queue
Handlers run on the main queue. Dispatch heavy work off, then reply on main:

```swift
channel.setMethodCallHandler { call, result in
  if call.method == "heavy" {
    DispatchQueue.global(qos: .userInitiated).async {
      let out = self.doHeavyWork(call.arguments)
      DispatchQueue.main.async { result(out) }   // reply on main
    }
  } else {
    result(FlutterMethodNotImplemented)
  }
}
```

## EventChannel sources on background threads
A sensor/listener may fire on a background thread. Sinks are generally safe to call from background threads on current engines, but if in doubt marshal to main before `sink.success(...)`. Always implement `onCancel` to stop the source.

## Symptoms & fixes
| Symptom | Cause | Fix |
|---|---|---|
| Android ANR dialog during a native call | Heavy work on UI thread in handler | Use `makeBackgroundTaskQueue()` |
| UI freezes on iOS during native call | Work on main queue | `DispatchQueue.global().async` then reply on main |
| Dart `Future` never completes | `result`/`sink` never called | Call exactly once on every code path |
| Crash "Reply already submitted" | `result` called twice | Guard so each path calls it once |
| Leaked sensor after navigating away | No `onCancel` | Stop the source in `onCancel` |

## Don't confuse with isolates
This is about the **native** thread. Heavy **Dart** CPU work is a different problem solved with isolates (`Isolate.run`) — see the `isolates-background` skill. Native heavy work is solved with platform threads/task queues here.
