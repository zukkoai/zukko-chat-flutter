# fastlane — build + store upload

## Contents
- [1. Layout](#1-layout)
- [2. Android Fastfile (supply)](#2-android-fastfile-supply)
- [3. iOS Fastfile (deliver)](#3-ios-fastfile-deliver)
- [4. Wiring into CI](#4-wiring-into-ci)

## 1. Layout

```
android/fastlane/Fastfile   # Play uploads via `supply`
ios/fastlane/Fastfile       # App Store via `deliver`
```
Build the binary with `flutter build` (so version/build-number flags apply), then let fastlane upload. Don't rebuild inside Gradle/Xcode and lose the Flutter flags.

## 2. Android Fastfile (supply)

```ruby
default_platform(:android)
platform :android do
  desc "Build AAB and upload to Play internal track"
  lane :internal do
    sh("flutter build appbundle --release " \
       "--build-number=#{ENV['CI_BUILD_NUMBER']}")   # auto-incremented, not hardcoded
    upload_to_play_store(
      track: "internal",
      aab: "../build/app/outputs/bundle/release/app-release.aab",
      json_key: ENV["PLAY_JSON_KEY_PATH"]              # service-account key from a secret
    )
  end
end
```
`upload_to_play_store` = the `supply` action. The Play **service-account JSON** comes from a CI secret (decode a base64 secret to a file at runtime).

## 3. iOS Fastfile (deliver)

```ruby
default_platform(:ios)
platform :ios do
  desc "Build IPA and upload to TestFlight"
  lane :beta do
    api_key = app_store_connect_api_key(
      key_id: ENV["ASC_KEY_ID"],
      issuer_id: ENV["ASC_ISSUER_ID"],
      key_filepath: ENV["ASC_KEY_PATH"]               # .p8 decoded from a secret
    )
    sh("flutter build ipa --release " \
       "--build-number=#{ENV['CI_BUILD_NUMBER']} " \
       "--export-options-plist=ExportOptions.plist")
    upload_to_testflight(
      api_key: api_key,
      ipa: "../build/ios/ipa/Runner.ipa"
    )
  end
end
```
`upload_to_testflight`/`upload_to_app_store` = `pilot`/`deliver`. Use the **App Store Connect API key** (`.p8`), **not** an Apple-ID password — 2FA breaks password auth.

## 4. Wiring into CI

```yaml
      - run: bundle exec fastlane android internal   # from android/
      - run: bundle exec fastlane ios beta           # from ios/, on macOS
```
- Provide `CI_BUILD_NUMBER` from the CI run number (auto-increment).
- Decode `PLAY_JSON_KEY`, `ASC_KEY` (.p8) from base64 secrets to files just before the lane (see `reference/signing-secrets.md`); delete them after.
