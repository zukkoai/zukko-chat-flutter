---
name: flavors-env
description: Sets up Flutter build flavors (dev/staging/prod) with per-environment config via Android productFlavors, iOS schemes, and --dart-define-from-file. Use when adding flavors, environments, multiple bundle IDs, or env-specific config.
---

You are a Flutter build engineer who wires dev/staging/prod flavors across Android, iOS, and Dart (Flutter 3.44 / Dart 3.12).

## When to use
- Adding build flavors or separate dev/staging/prod environments to an app.
- Needing distinct bundle IDs/app names/icons per environment, or env-specific config (base URLs, keys).

## Detect first
Before writing config, match the existing project — don't impose a parallel setup:
- **Android**: does `android/app/build.gradle.kts` already declare `flavorDimensions`/`productFlavors`? Reuse the dimension name and suffix scheme.
- **iOS**: open `ios/Runner.xcodeproj` — are there existing schemes (`Runner-dev`, etc.) and `.xcconfig` files? Match their naming.
- **Dart**: is config read via `appFlavor`, `--dart-define`, or separate `main_*.dart` entry points? Follow the existing pattern.
- **Config source**: look for `config/*.json` (dart-define-from-file) before adding a new mechanism.

## Core rules

| Do | Avoid (known AI mistakes) |
|----|----|
| Read the flavor via the **`appFlavor`** constant (Flutter 3.19+) | `String.fromEnvironment('FLAVOR')` hack — stale, no longer needed |
| Define Android `productFlavors` in **`build.gradle.kts`** (Kotlin DSL) with `applicationIdSuffix` | Editing legacy Groovy `build.gradle` — `flutter create` is Kotlin DSL now |
| Mark every iOS scheme **"Shared"** | Leaving schemes unshared → CI/`flutter build` can't find them |
| Inject config via **`--dart-define-from-file=config/dev.json`** | Hardcoding URLs/keys per flavor in Dart |
| Put secrets in native key stores / a backend | Putting secrets in `.env` assets or `--dart-define` (both extractable) |

### Android — `android/app/build.gradle.kts`
```kotlin
android {
    flavorDimensions += "env"
    productFlavors {
        create("dev")  { dimension = "env"; applicationIdSuffix = ".dev";  resValue("string", "app_name", "MyApp Dev") }
        create("stg")  { dimension = "env"; applicationIdSuffix = ".stg";  resValue("string", "app_name", "MyApp Stg") }
        create("prod") { dimension = "env";                                resValue("string", "app_name", "MyApp")     }
    }
}
```

### Read the active flavor (Dart)
```dart
// appFlavor is set automatically from --flavor; no --dart-define needed.
final env = appFlavor ?? 'prod';
```

### Run / build
```bash
flutter run   --flavor dev  -t lib/main_dev.dart  --dart-define-from-file=config/dev.json
flutter build apk --flavor prod -t lib/main_prod.dart --dart-define-from-file=config/prod.json
```

## Gotchas
- **`String.fromEnvironment('FLAVOR')` is a known AI mistake** — it only works if you manually pass `--dart-define=FLAVOR=...`. Use the built-in **`appFlavor`** constant instead (Flutter 3.19+).
- **Unshared iOS schemes are a known AI mistake** — a scheme defaults to user-local; CI and `flutter build ipa` silently fail to find it. Tick **"Shared"** in *Manage Schemes* and commit `xcshareddata/xcschemes/*.xcscheme`.
- **Secrets in `.env`/`flutter_dotenv` assets are extractable plaintext** — the asset ships inside the bundle; anyone can unzip it. `--dart-define` is obfuscation-grade and **Dart-only** (not visible to native Swift/Kotlin) but still extractable. Both are fine for *non-secret* config only. Cross-ref the `security` skill for real secret handling.
- **Android `dimension` is required** on every flavor once `flavorDimensions` is declared, or Gradle sync fails.
- **iOS needs the `.xcconfig` wired into the scheme's build config** (Debug-dev/Release-dev) — adding the file isn't enough; set it under *Project → Info → Configurations*.

## Common mistakes
- `String.fromEnvironment('FLAVOR')` → use `appFlavor`.
- Groovy `build.gradle` edits → use the generated `build.gradle.kts`.
- Schemes left unshared → mark Shared and commit the xcscheme.
- Secrets in `.env`/dart-define → keep only non-secret config there.
- One bundle ID for all flavors → add `applicationIdSuffix` so dev/prod install side by side.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, native config done, no secrets).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- Android `productFlavors` (Kotlin DSL, suffixes, app names/icons): read `reference/android-flavors.md`.
- iOS schemes + `.xcconfig` step-by-step (mark Shared, Info.plist vars): read `reference/ios-flavors.md`.
- `--dart-define-from-file`, `appFlavor`, config JSON shape: read `reference/dart-define.md`.
- Per-flavor `main_*.dart` entry points + shared bootstrap: read `reference/entry-points.md`.
