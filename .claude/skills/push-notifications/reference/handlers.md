# Handlers — foreground / background / terminated matrix

## Contents
- [1. State matrix](#1-state-matrix)
- [2. The background handler (vm:entry-point)](#2-the-background-handler-vmentry-point)
- [3. Full main() wiring](#3-full-main-wiring)
- [4. Tap routing](#4-tap-routing)

## 1. State matrix

What runs depends on app state **and** payload type. `notification`-only messages let the OS draw a banner but do **not** reliably run your Dart code; **data** messages do.

| App state | `notification`-only | `data` (or notification+data) |
|---|---|---|
| **Foreground** | Nothing shown; `onMessage` fires | `onMessage` fires → you show a local notification |
| **Background** | OS shows banner; **no** code until tapped | Background handler runs (data); banner if `notification` included |
| **Terminated** | OS shows banner (Android); tap launches app | Background handler runs (data, best-effort); `getInitialMessage()` on launch |

Takeaway: for guaranteed code execution in all states, **send data messages** and display notifications yourself.

## 2. The background handler (vm:entry-point)

Runs in a **separate isolate** with no access to your app's state — re-initialize what it needs.

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // separate isolate → must re-init
  final data = message.data;
  // Persist, sync a badge, or show a local notification.
  // Keep it fast — the OS budget for background work is short.
}
```

Rules:
- **Top-level function or a static method** — never a closure or instance method.
- **`@pragma('vm:entry-point')`** is mandatory. Without it the tree-shaker strips the function in `--release`; the handler silently never fires (debug masks this).
- Don't touch UI or app-scoped singletons; they don't exist in this isolate.

## 3. Full main() wiring

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(); // iOS prompt + Android 13 POST_NOTIFICATIONS

  await initLocalNotifications(); // create channel (see local-notifications.md)

  // Foreground: FCM shows nothing — display it yourself.
  FirebaseMessaging.onMessage.listen(showFromRemoteMessage);

  // Token: send to backend, then watch for rotation.
  final token = await messaging.getToken();
  await syncToken(token);
  messaging.onTokenRefresh.listen(syncToken);

  runApp(const MyApp());
}
```

## 4. Tap routing

Handle both entry points — a tap from background and a tap that cold-launches the app:

```dart
// Cold launch from a notification tap (terminated → opened):
final initial = await FirebaseMessaging.instance.getInitialMessage();
if (initial != null) routeFromMessage(initial);

// Tap while app was in the background:
FirebaseMessaging.onMessageOpenedApp.listen(routeFromMessage);
```

Read the route/id from `message.data` and navigate. For local-notification taps (foreground display), use the plugin's `onDidReceiveNotificationResponse` payload. Routing details: cross-ref `deep-linking` and `navigation`.
