# GitHub Actions — full Flutter workflow

## Contents
- [1. Lint + test job (Linux)](#1-lint--test-job-linux)
- [2. Android build + sign (AAB)](#2-android-build--sign-aab)
- [3. iOS build (macOS)](#3-ios-build-macos)
- [4. Caching](#4-caching)
- [5. Secrets used](#5-secrets-used)

Uses `subosito/flutter-action` to install Flutter. Order: deps → format → analyze → test → build → sign → distribute.

## 1. Lint + test job (Linux)

```yaml
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, flutter-version: 3.44.x, cache: true }
      - run: flutter pub get               # NOT `flutter packages get`
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test --coverage       # runs golden tests too — see note
```
> **Goldens:** golden tests are renderer/OS-sensitive. Run them on the **same OS** that generated the baselines (commonly macOS) or they flake. If goldens live in a separate suite, run that suite on a macOS job (see §3).

## 2. Android build + sign (AAB)

```yaml
  android:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      # Decode signing material from base64 secrets (see signing-secrets.md):
      - run: echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/upload.jks
      - run: |
          cat > android/key.properties <<EOF
          storeFile=upload.jks
          storePassword=${{ secrets.STORE_PASSWORD }}
          keyAlias=${{ secrets.KEY_ALIAS }}
          keyPassword=${{ secrets.KEY_PASSWORD }}
          EOF
      - run: |
          flutter build appbundle --release \
            --build-name=$(grep '^version:' pubspec.yaml | sed 's/version: //;s/+.*//') \
            --build-number=${{ github.run_number }} \
            --obfuscate --split-debug-info=build/symbols
      - uses: actions/upload-artifact@v4
        with: { name: app-release-aab, path: build/app/outputs/bundle/release/*.aab }
```
- **Build number = `github.run_number`** → always increases, never a duplicate `versionCode`.
- `--obfuscate --split-debug-info` → archive `build/symbols` and upload to your crash tool (cross-ref `observability`).

## 3. iOS build (macOS)

```yaml
  ios:
    needs: test
    runs-on: macos-latest         # iOS builds REQUIRE macOS
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      # Install certs/profiles + ASC API key from secrets (see signing-secrets.md)
      - run: |
          flutter build ipa --release \
            --build-number=${{ github.run_number }} \
            --export-options-plist=ios/ExportOptions.plist
      - uses: actions/upload-artifact@v4
        with: { name: app-ipa, path: build/ios/ipa/*.ipa }
```
Distribute with fastlane `deliver` or `xcrun altool`/`notarytool` using the App Store Connect API key (`reference/fastlane.md`, `reference/signing-secrets.md`).

## 4. Caching

`subosito/flutter-action@v2` with `cache: true` caches the SDK + pub. Add Gradle cache for Android speed:
```yaml
      - uses: actions/cache@v4
        with:
          path: ~/.gradle/caches
          key: gradle-${{ hashFiles('android/**/*.gradle*') }}
```

## 5. Secrets used

Set in repo → Settings → Secrets and variables → Actions (never in the repo):
`KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, `ASC_KEY_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`. Details in `reference/signing-secrets.md`.
