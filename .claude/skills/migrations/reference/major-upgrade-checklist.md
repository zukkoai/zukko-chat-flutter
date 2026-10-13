# Major Flutter upgrade — step-by-step checklist

## Contents
- [0. Before you start](#0-before-you-start)
- [1. Pin the new SDK (fvm)](#1-pin-the-new-sdk-fvm)
- [2. Dart side: pubspec + deps](#2-dart-side-pubspec--deps)
- [3. Automated code migration](#3-automated-code-migration)
- [4. Android native cascade](#4-android-native-cascade)
- [5. iOS native cascade](#5-ios-native-cascade)
- [6. Verify](#6-verify)
- [7. Incremental jumps](#7-incremental-jumps)

A major Flutter bump is never Dart-only. It cascades into Gradle/AGP/Kotlin/SDK on Android and CocoaPods/Podfile on iOS, plus transitive package constraints. Work one section at a time, committing checkpoints.

## 0. Before you start
- Read the official **breaking-changes** doc for the target version (and every version you skip).
- Ensure the tree is clean and tests pass on the *current* version first.
- Skim `flutter pub outdated` to see which deps will need bumps.

## 1. Pin the new SDK (fvm)
```bash
fvm install 3.44.0
fvm use 3.44.0          # rewrites .fvmrc — commit it
fvm flutter --version   # confirm
```
Do **not** `flutter upgrade` (mutates the global SDK — breaks other projects/CI).

## 2. Dart side: pubspec + deps
- Update `environment:` constraints:
  ```yaml
  environment:
    sdk: ^3.12.0
    flutter: ">=3.44.0"
  ```
- Resolve dependency conflicts:
  ```bash
  fvm flutter pub outdated      # see current / upgradable / resolvable / latest
  fvm flutter pub upgrade --major-versions   # bump within solvable constraints
  fvm flutter pub get
  ```
- If a package blocks resolution, bump it manually to a version compatible with the new SDK; check its changelog for breaking changes.

## 3. Automated code migration
```bash
fvm dart fix --dry-run
fvm dart fix --apply
```
(`dart migrate` no longer exists — see `dart-fix.md`.) Then sweep deprecated APIs from `deprecated-apis.md`.

## 4. Android native cascade
A new Flutter major usually requires newer Android tooling. Check and bump:
- **AGP** in `android/settings.gradle.kts`:
  ```kotlin
  plugins { id("com.android.application") version "8.7.0" apply false }
  ```
- **Gradle wrapper** in `android/gradle/wrapper/gradle-wrapper.properties`:
  ```
  distributionUrl=https\://services.gradle.org/distributions/gradle-8.10-all.zip
  ```
- **Kotlin** plugin version (in `settings.gradle.kts`).
- `compileSdk` / `minSdk` / `targetSdk` in `android/app/build.gradle.kts` — Flutter sets a minimum; raise to match.
- Run `cd android && ./gradlew clean` if the build caches stale config.

> AGP ↔ Gradle ↔ Kotlin ↔ Android Studio versions are coupled; mismatches surface as cryptic Gradle errors. Bump them as a set to versions the Flutter release notes call out.

> **Groovy is not deprecated.** Kotlin DSL (`.gradle.kts`) is the default for *new* projects since Flutter 3.29; existing Groovy `.gradle` projects keep working and need not migrate. What changed is the **imperative `apply` of Flutter's Gradle plugins → the declarative `plugins {}` DSL**. The `.kts` snippets above are the new-project default, not a forced migration.

## 5. iOS native cascade
- **Podfile** `platform :ios, '13.0'` — raise to the minimum the new SDK/plugins require.
- Refresh pods after dep bumps:
  ```bash
  cd ios && pod repo update && pod install
  ```
- If `Podfile.lock` conflicts, delete `ios/Pods` + `Podfile.lock` and re-run `pod install`.
- Bump `IPHONEOS_DEPLOYMENT_TARGET` in Xcode if a plugin demands it.

## 6. Verify
```bash
fvm flutter clean && fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug      # Android compiles
fvm flutter build ios --no-codesign # iOS compiles
```

## 7. Incremental jumps
Don't leap several majors at once. Upgrade one major at a time, running `analyze` + tests between steps, so a regression is isolated to a single bump rather than buried in a giant diff.
