# Testing & verifying deep links

## Contents
- [Verify the hosted files first](#verify-the-hosted-files-first)
- [Android: adb](#android-adb)
- [Android: check verification status](#android-check-verification-status)
- [iOS: simulator & device](#ios-simulator--device)
- [Cold start vs running](#cold-start-vs-running)
- [Troubleshooting matrix](#troubleshooting-matrix)

## Verify the hosted files first
Before debugging the app, confirm the well-known files are actually served correctly.

```bash
# Android — must return the JSON with package + fingerprints, HTTP 200, no redirect
curl -sSL -D - https://example.com/.well-known/assetlinks.json

# iOS — must return Content-Type: application/json, HTTP 200, NO redirect, no extension
curl -sSL -D - https://example.com/.well-known/apple-app-site-association
```
Check the headers: a `301/302` (redirect) or `text/html` content-type means verification will fail. Apple's own validator and Google's "Statement List Generator and Tester" can also check these.

## Android: adb
Simulate an incoming link:
```bash
# App Link (https)
adb shell am start -W -a android.intent.action.VIEW \
  -c android.intent.category.BROWSABLE \
  -d "https://example.com/product/42" com.example.app

# Custom scheme
adb shell am start -a android.intent.action.VIEW -d "myapp://callback?token=x" com.example.app
```
If it opens the app and lands on the right screen, routing works. If it opens a browser, verification or the intent-filter is wrong.

## Android: check verification status
```bash
# Re-trigger / inspect App Links verification (Android 12+)
adb shell pm verify-app-links --re-verify com.example.app
adb shell pm get-app-links com.example.app
```
Look for `verified` next to your domain. `legacy_failure`/`1024` means the `assetlinks.json` didn't match (wrong fingerprint, redirect, or not reachable).

## iOS: simulator & device
```bash
# Simulator — open a Universal Link
xcrun simctl openurl booted "https://example.com/product/42"

# Custom scheme
xcrun simctl openurl booted "myapp://callback?token=x"
```
On a **real device**, the reliable test is tapping the link from **Notes / Messages / another app** — typing it in Safari's address bar or tapping it on the *same* domain often won't trigger a Universal Link. AASA changes are cached, so test after a fresh install if you just updated the file.

## Cold start vs running
Test both states for each platform:
- **Cold start:** force-quit the app, then fire the link → app launches straight onto the target screen.
- **Running:** open the app, background it, then fire the link → app foregrounds and navigates.
Cold start is where `initialLocation` clobbering and null `extra:` bugs show up.

## Troubleshooting matrix
| Symptom | Likely cause | Fix |
|---|---|---|
| Link opens browser, not app (Android) | `assetlinks.json` missing/redirected/wrong fingerprint | `curl` it; add release + Play SHA-256; remove redirect |
| Link opens Safari, not app (iOS) | AASA wrong name/MIME/redirect, or entitlement missing | No extension, `application/json`, no redirect; add `applinks:` entitlement |
| App opens but lands on `/home` | `initialLocation` set, or auth dropped destination | Remove `initialLocation`; preserve `from` in redirect |
| Works in debug, browser in release (Android) | Release/Play signing fingerprint not in `assetlinks.json` | Add release + Play App Signing SHA-256 |
| `extra` is null on cold start | Passed data via `extra:` | Use path/query params instead |
| iOS link works from simulator, not device | AASA cache / typed-in-Safari | Fresh install; tap from another app |
