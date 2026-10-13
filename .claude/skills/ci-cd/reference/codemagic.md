# Codemagic — codemagic.yaml

## Contents
- [1. Workflow skeleton](#1-workflow-skeleton)
- [2. Build numbers](#2-build-numbers)
- [3. Signing + secrets](#3-signing--secrets)
- [4. Publishing](#4-publishing)

Codemagic runs macOS build machines by default — good for iOS + goldens. Config lives in `codemagic.yaml` at the repo root.

## 1. Workflow skeleton

```yaml
workflows:
  release:
    name: Release
    instance_type: mac_mini_m2        # macOS → builds both Android and iOS
    environment:
      flutter: stable
      groups: [signing, store_keys]   # secret groups from the Codemagic UI
    cache:
      cache_paths:
        - $HOME/.pub-cache
        - $HOME/.gradle/caches
    scripts:
      - name: Deps
        script: flutter pub get        # NOT `flutter packages get`
      - name: Format + analyze
        script: |
          dart format --output=none --set-exit-if-changed .
          flutter analyze
      - name: Test
        script: flutter test
      - name: Build AAB
        script: |
          flutter build appbundle --release \
            --build-number=$PROJECT_BUILD_NUMBER \
            --obfuscate --split-debug-info=build/symbols
      - name: Build IPA
        script: |
          flutter build ipa --release \
            --build-number=$PROJECT_BUILD_NUMBER \
            --export-options-plist=/Users/builder/export_options.plist
    artifacts:
      - build/**/outputs/bundle/release/*.aab
      - build/ios/ipa/*.ipa
      - build/symbols/**               # keep for symbolication
```

## 2. Build numbers

Use Codemagic's auto-incrementing `$PROJECT_BUILD_NUMBER` (or `latest_build_number` helpers) for `--build-number` — **never hardcode**; a duplicate is rejected at upload. Keep `--build-name` in sync with `pubspec.yaml` `version:`.

## 3. Signing + secrets

- Add the **Android keystore** and **iOS distribution certificate + provisioning profile** via Codemagic's code-signing UI (encrypted, not in the repo).
- Store the **App Store Connect API key** (`.p8` + key id + issuer) and any `FIREBASE_TOKEN` in **environment variable groups** marked secret. Reference them by `groups:`.
- Never paste secrets inline in `codemagic.yaml`.

## 4. Publishing

```yaml
    publishing:
      app_store_connect:
        api_key: $APP_STORE_CONNECT_PRIVATE_KEY
        key_id: $APP_STORE_CONNECT_KEY_IDENTIFIER
        issuer_id: $APP_STORE_CONNECT_ISSUER_ID
        submit_to_testflight: true
      google_play:
        credentials: $GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
        track: internal
```
For Firebase App Distribution, use the `firebase_app_distribution` integration or call the CLI with `$FIREBASE_TOKEN` from a secret group.
