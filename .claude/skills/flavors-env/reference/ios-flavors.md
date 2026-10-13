# iOS flavors (schemes + xcconfig)

iOS has no `productFlavors`. You model flavors with **build configurations + `.xcconfig` files + schemes**. Do this in Xcode (`ios/Runner.xcworkspace`), not by hand-editing `project.pbxproj`.

## 1. Create xcconfig files

Add one per flavor under `ios/Flutter/`, e.g. `ios/Flutter/dev.xcconfig`:

```xcconfig
#include "Generated.xcconfig"          // Flutter's generated values — keep this
APP_NAME = MyApp Dev
BUNDLE_ID_SUFFIX = .dev
```

`Generated.xcconfig` is written by the Flutter tool on each build; always `#include` it.

## 2. Duplicate build configurations

In Xcode: **Project "Runner" → Info → Configurations**. Duplicate `Debug`/`Release`/`Profile` into per-flavor pairs:

```
Debug-dev, Release-dev, Profile-dev
Debug-stg, Release-stg, Profile-stg
Debug-prod, Release-prod, Profile-prod
```

For each, set its config file to the matching `.xcconfig` (the dropdown next to the config name).

## 3. Wire bundle ID + display name

**Runner target → Build Settings**:
- `PRODUCT_BUNDLE_IDENTIFIER` = `com.acme.app$(BUNDLE_ID_SUFFIX)`
- In `Info.plist`, set `CFBundleDisplayName` = `$(APP_NAME)`.

Variables resolve from the active configuration's xcconfig.

## 4. Create schemes — and mark them Shared

**Product → Scheme → Manage Schemes**. Create `Runner-dev`, `Runner-stg`, `Runner-prod`. For each, set Run/Test/Profile/Archive to the matching `*-dev` build configuration.

**Critical:** tick the **"Shared"** checkbox for every scheme.

- Unshared schemes live in `xcuserdata/` (git-ignored, user-local).
- CI and `flutter build ipa --flavor dev` look up the scheme by name and **fail silently** if it's user-local.
- Sharing writes `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner-dev.xcscheme` — **commit that file**.

## 5. Match Flutter's --flavor to the scheme name

`flutter run --flavor dev` expects a scheme literally named `dev` **or** `Runner-dev`/`Dev`. Flutter matches case-insensitively against the `--flavor` value. Keep the scheme name aligned with the Android flavor name.

```bash
flutter build ipa --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/dev.json
```

## Per-flavor GoogleService-Info.plist (Firebase)

Don't add all plists to the target. Use a **Run Script build phase** that copies the right one based on `$CONFIGURATION`, or keep them in `ios/config/<flavor>/GoogleService-Info.plist` and copy in the phase.

## Checklist

- [ ] One xcconfig per flavor, each `#include "Generated.xcconfig"`.
- [ ] Per-flavor Debug/Release/Profile configurations, each pointing at its xcconfig.
- [ ] `PRODUCT_BUNDLE_IDENTIFIER` uses `$(BUNDLE_ID_SUFFIX)`.
- [ ] Every scheme marked **Shared**; `xcshareddata/xcschemes/*.xcscheme` committed.
