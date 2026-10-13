# Displaying with flutter_local_notifications

## Contents
- [1. Init + channel](#1-init--channel)
- [2. Show from a RemoteMessage](#2-show-from-a-remotemessage)
- [3. Taps](#3-taps)
- [4. iOS foreground presentation](#4-ios-foreground-presentation)

Why this package: FCM is transport only and draws **nothing** in the foreground. `flutter_local_notifications` is what actually displays a banner, owns Android channels, and reports taps with a payload.

## 1. Init + channel

```dart
final fln = FlutterLocalNotificationsPlugin();

const channel = AndroidNotificationChannel(
  'high_importance_channel', // must match the manifest meta-data id
  'Important Notifications',
  importance: Importance.high,
);

Future<void> initLocalNotifications() async {
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await fln.initialize(settings,
      onDidReceiveNotificationResponse: (resp) => routeFromPayload(resp.payload));

  // Create the channel once (no-op if it exists). Required on Android 8+.
  await fln
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}
```

The channel id must match the `default_notification_channel_id` meta-data so background FCM auto-posts and your foreground notifications land on the same channel.

## 2. Show from a RemoteMessage

```dart
void showFromRemoteMessage(RemoteMessage m) {
  final n = m.notification;
  fln.show(
    n.hashCode,
    n?.title ?? m.data['title'],
    n?.body ?? m.data['body'],
    NotificationDetails(
      android: AndroidNotificationDetails(channel.id, channel.name,
          importance: Importance.high, priority: Priority.high),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: m.data['route'], // carry deep-link target for the tap
  );
}
```

## 3. Taps

- Foreground display → `onDidReceiveNotificationResponse` (set in `initialize`) gives you the `payload`.
- FCM-drawn banners (background) → `FirebaseMessaging.onMessageOpenedApp` / `getInitialMessage()` (see `reference/handlers.md`).

Carry a stable route key (`m.data['route']`) and dispatch via your router — cross-ref `deep-linking` and `navigation`.

## 4. iOS foreground presentation

By default iOS suppresses the system banner while the app is foreground (that's why you draw a local one). If you also want the **system** banner in foreground, enable it:
```dart
await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
  alert: true, badge: true, sound: true,
);
```
Avoid double banners — pick one path (local notification **or** system presentation) for foreground, not both.
