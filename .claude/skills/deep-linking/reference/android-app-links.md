# Android App Links

## Contents
- [Two required pieces](#two-required-pieces)
- [1. Manifest intent-filter](#1-manifest-intent-filter)
- [2. Host assetlinks.json](#2-host-assetlinksjson)
- [Getting the SHA-256 fingerprints](#getting-the-sha-256-fingerprints)
- [Custom scheme (fallback)](#custom-scheme-fallback)
- [flutter_deeplinking_enabled](#flutter_deeplinking_enabled)

## Two required pieces
An App Link only opens your app directly (no browser chooser) when **both** are true:
1. The manifest declares an `<intent-filter>` with `android:autoVerify="true"` for the `https` host.
2. The domain serves a valid `/.well-known/assetlinks.json` listing your package + the signing cert SHA-256.

Miss either and the link opens the browser.

## 1. Manifest intent-filter
In `android/app/src/main/AndroidManifest.xml`, inside the main `<activity android:name=".MainActivity">`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="example.com" />
    <!-- optional path scoping -->
    <data android:pathPrefix="/app" />
</intent-filter>
```
- `android:autoVerify="true"` triggers Android's verification against `assetlinks.json` at install/update.
- Keep `BROWSABLE` + `DEFAULT` categories — without them the link won't route.
- You can add `android:scheme="http"` too, but `https` is what verifies.

## 2. Host assetlinks.json
Serve at exactly `https://example.com/.well-known/assetlinks.json` over HTTPS (valid cert, no redirect):

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example.app",
    "sha256_cert_fingerprints": [
      "AA:BB:CC:...:debug",
      "11:22:33:...:release"
    ]
  }
}]
```
- `package_name` = your `applicationId`.
- List **both** debug and release SHA-256 fingerprints (they differ). Omitting the release one is the classic "works in debug, browser in production" bug.

## Getting the SHA-256 fingerprints
```bash
# Debug keystore (default password 'android')
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android

# Release keystore
keytool -list -v -keystore /path/to/release.keystore -alias your_alias
```
If you publish via Play App Signing, also add the **Play-managed** signing cert SHA-256 from Play Console → App integrity. Many "verified in CI, fails in production" cases are this missing fingerprint.

## Custom scheme (fallback)
For unverified custom schemes (e.g. OAuth redirect), add a separate intent-filter — do **not** put `autoVerify` on it:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="myapp" android:host="callback" />
</intent-filter>
```

## flutter_deeplinking_enabled
Recent Flutter routes App Links through the framework (and go_router) by default. If you need to force Flutter's deep-link handling, set in the `<application>` or `<activity>` meta-data:
```xml
<meta-data android:name="flutter_deeplinking_enabled" android:value="true" />
```
Check your Flutter version's docs — on current versions go_router handles links without extra flags, but this meta-data resolves cases where the native side intercepts first.
