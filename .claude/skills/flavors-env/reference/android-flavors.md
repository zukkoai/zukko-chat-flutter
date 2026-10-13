# Android flavors (Kotlin DSL)

Edit `android/app/build.gradle.kts` (current `flutter create` is Kotlin DSL, not Groovy).

## productFlavors

```kotlin
android {
    // ...
    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"        // com.acme.app.dev
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "MyApp Dev")
        }
        create("stg") {
            dimension = "env"
            applicationIdSuffix = ".stg"
            versionNameSuffix = "-stg"
            resValue("string", "app_name", "MyApp Stg")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "MyApp")
        }
    }
}
```

- **`flavorDimensions += "env"`** is required before any flavor; every flavor must set `dimension = "env"`.
- **`applicationIdSuffix`** lets dev/stg/prod install side by side without colliding. Prod has none (base ID).
- **`versionNameSuffix`** is cosmetic; it does not affect the Play versionCode.

## App name via resValue

`resValue("string", "app_name", ...)` injects a `@string/app_name` resource. Wire the manifest to use it:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application android:label="@string/app_name" ... >
```

Remove any hardcoded `android:label="MyApp"` so the per-flavor value wins.

## Per-flavor icons / resources

Drop flavor-specific resources under `src/<flavor>/res/...`. Gradle merges them over `src/main`:

```
android/app/src/
  main/res/mipmap-*/ic_launcher.png   # default (prod)
  dev/res/mipmap-*/ic_launcher.png    # dev override
  stg/res/mipmap-*/ic_launcher.png
```

Same pattern for `src/<flavor>/res/values/colors.xml`, splash assets, etc. No Gradle wiring needed — folder name = flavor name.

## Per-flavor google-services.json (Firebase)

If each flavor is a distinct Firebase app, place its file at `android/app/src/<flavor>/google-services.json`. Gradle picks the matching one per build.

## Verify

```bash
flutter build apk --flavor dev -t lib/main_dev.dart
# installs as com.acme.app.dev with label "MyApp Dev"
```
