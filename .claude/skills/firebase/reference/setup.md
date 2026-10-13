# Firebase setup — flutterfire configure + native steps

## Contents
- [1. CLI + configure](#1-cli--configure)
- [2. Initialize in main](#2-initialize-in-main)
- [3. Android native steps](#3-android-native-steps)
- [4. iOS/macOS native steps](#4-iosmacos-native-steps)
- [5. App Check](#5-app-check)
- [6. Emulator Suite (local dev)](#6-emulator-suite-local-dev)

## 1. CLI + configure

```bash
npm i -g firebase-tools && firebase login
dart pub global activate flutterfire_cli
flutterfire configure   # pick project + platforms → writes lib/firebase_options.dart
flutter pub add firebase_core firebase_auth cloud_firestore
```

`flutterfire configure` registers each platform app and **generates `lib/firebase_options.dart`**. Re-run it when you add a platform or change projects. Never hand-edit that file or hardcode the config.

## 2. Initialize in main

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
```

Using any Firebase service before this throws `[core/no-app]`.

## 3. Android native steps

`flutterfire configure` usually writes these, but verify:
- `android/app/google-services.json` present.
- `android/settings.gradle` (or `android/build.gradle`) applies the google-services plugin; `android/app/build.gradle` has `id "com.google.gms.google-services"`.
- **minSdk**: Firebase Auth needs `minSdkVersion 23`. Set it in `android/app/build.gradle`.
- For release, add your app's **SHA-1/SHA-256** in the Firebase console (required for Google Sign-In / Phone Auth / App Check).

## 4. iOS/macOS native steps

- `ios/Runner/GoogleService-Info.plist` present and added to the Runner target in Xcode.
- Set a deployment target Firebase supports (iOS 13+ is safe); run `pod install` in `ios/`.
- For Sign in with Apple / Google Sign-In, add URL schemes and capabilities in Xcode.

## 5. App Check

App Check attests that requests come from your genuine app. Pair it with security rules.

```dart
import 'package:firebase_app_check/firebase_app_check.dart';

await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.appAttest,
);
```
- Register providers in the Firebase console; enforce App Check on Firestore/Storage once verified.
- Use **debug providers** in development (register the debug token) so local runs aren't blocked.

## 6. Emulator Suite (local dev)

```bash
firebase init emulators        # auth, firestore, functions
firebase emulators:start
```

```dart
if (kDebugMode) {
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
}
```
- Develop and test rules against the emulator — no production data, free, fast.
- Keep emulator wiring behind `kDebugMode` so it never ships.

## Config files note

`firebase_options.dart`, `google-services.json`, and `GoogleService-Info.plist` are **config, not secrets** (they contain public identifiers). Keep them out of public repos as good hygiene, but your actual protection is **security rules + App Check**, not concealment.
