# Payloads — notification vs data messages

## Contents
- [1. The distinction](#1-the-distinction)
- [2. Server payload shapes](#2-server-payload-shapes)
- [3. Reading on the client](#3-reading-on-the-client)
- [4. Rules of thumb](#4-rules-of-thumb)

## 1. The distinction

FCM messages carry two optional blocks:
- **`notification`** — title/body the OS renders automatically when the app is **not** foreground. Convenient, but your Dart code does **not** reliably run for these in background/terminated; tapping just opens the app.
- **`data`** — arbitrary key/value strings delivered to your handler. **Data is what reliably triggers your code** in all app states, and what you read to route and to build a custom local notification.

For guaranteed behavior, send **data** (optionally alongside `notification`) and display the banner yourself.

## 2. Server payload shapes

HTTP v1 API (`POST https://fcm.googleapis.com/v1/projects/<project>/messages:send`):

Data-only (recommended for code that must run):
```json
{ "message": {
    "token": "<device-token>",
    "data": { "type": "chat", "route": "/chat/42", "title": "New message", "body": "Hi" },
    "android": { "priority": "high" },
    "apns": { "headers": { "apns-priority": "10" },
              "payload": { "aps": { "content-available": 1 } } }
}}
```

Notification + data (OS draws banner in background; data available on tap):
```json
{ "message": {
    "token": "<device-token>",
    "notification": { "title": "New message", "body": "Hi" },
    "data": { "route": "/chat/42" }
}}
```

- `"content-available": 1` (apns) wakes the app for **background data** processing on iOS.
- `android.priority: "high"` is needed for prompt/wake delivery; default may be deferred.

## 3. Reading on the client

```dart
final route = message.data['route'];      // routing target
final type  = message.data['type'];        // dispatch by message kind
// message.notification?.title / .body when a notification block is present
```

## 4. Rules of thumb

- **Need to run code in background/terminated?** Send **data**, set `android.priority: high` and apns `content-available: 1`.
- **Just want a simple banner with no logic?** A `notification` block is fine, but you lose foreground display and reliable code execution.
- **Want full control of look + foreground display?** Send data and render with `flutter_local_notifications` (see `reference/local-notifications.md`).
- Keep payloads small (FCM limit ~4KB) and **never** put secrets/PII in `data` — it's readable on-device and in transit logs.
