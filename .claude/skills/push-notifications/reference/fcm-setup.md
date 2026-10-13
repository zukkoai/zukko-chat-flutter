# FCM + local notifications — native setup

## Contents
- [1. Packages](#1-packages)
- [2. Android — manifest, channel meta-data, permission](#2-android--manifest-channel-meta-data-permission)
- [3. iOS — APNs .p8 key + Xcode capabilities](#3-ios--apns-p8-key--xcode-capabilities)
- [4. Verify checklist](#4-verify-checklist)

## 1. Packages

```bash
flutter pub add firebase_messaging flutter_local_notifications
```
Firebase must already be configured (`flutterfire configure`, `Firebase.initializeApp`) — see `firebase`. Version-sensitive: read `pub.dev/packages/firebase_messaging/changelog` and `pub.dev/packages/flutter_local_notifications/changelog`.

## 2. Android — manifest, channel meta-data, permission

`android/app/src/main/AndroidManifest.xml` — inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```
Inside `<application>`, declare the default channel used when the app is in the background and FCM auto-posts a `notification` message:
```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="high_importance_channel"/>
```
- **Android 13 (API 33)+**: `POST_NOTIFICATIONS` is a **runtime** permission — `FirebaseMessaging.instance.requestPermission()` (or the local-notifications plugin's Android request) shows the prompt. Without the grant, nothing is shown.
- **Android 8 (API 26)+**: every notification needs a **channel**. Create one at startup (see `reference/local-notifications.md`). The `meta-data` channel id above must match a channel you actually create, or FCM auto-posts get dropped.
- `google-services.json` must be at `android/app/google-services.json` and the google-services Gradle plugin applied (handled by `flutterfire configure`).
- `minSdkVersion 21`+ in `android/app/build.gradle.kts`.

## 3. iOS — APNs .p8 key + Xcode capabilities

FCM on iOS is a wrapper over **APNs** — without APNs configured, push silently fails.

1. **Create an APNs auth key** in the Apple Developer portal → Keys → "+" → enable **Apple Push Notifications service (APNs)** → download the **`.p8`** (one-time download; keep it safe). Note the **Key ID** and your **Team ID**.
2. **Upload it to Firebase**: Firebase console → Project Settings → Cloud Messaging → Apple app config → **APNs Authentication Key** → upload `.p8` + Key ID + Team ID. (Prefer the .p8 auth key over per-environment .p12 certs — one key covers dev + prod.)
3. **Xcode capabilities** (open `ios/Runner.xcworkspace`, target Runner → Signing & Capabilities → "+ Capability"):
   - **Push Notifications** → adds `aps-environment` to `Runner.entitlements`.
   - **Background Modes** → check **Remote notifications** (and Background fetch if you process data in the background).
4. **Real device only** — the iOS Simulator cannot register with APNs or receive remote push. Test on hardware.
5. For provisional/quiet permission or to control the prompt, pass options to `requestPermission`.

`ios/Runner/Info.plist` for data-only background processing already works via Background Modes; no extra key needed for standard alerts.

## 4. Verify checklist

- [ ] `POST_NOTIFICATIONS` in manifest; runtime request wired (Android 13+).
- [ ] Default channel `meta-data` id matches a channel you create at startup.
- [ ] `google-services.json` present; Gradle plugin applied.
- [ ] APNs `.p8` uploaded to Firebase (Key ID + Team ID).
- [ ] Push Notifications + Background Modes (Remote notifications) capabilities enabled.
- [ ] Tested on a **real iOS device**, not the simulator.
