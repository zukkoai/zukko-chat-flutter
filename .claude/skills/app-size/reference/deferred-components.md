# Deferred components (Android)

Deferred components split install-time Dart code and assets into separate **Play feature modules** downloaded on demand via `loadLibrary()`. This shrinks the **initial** download.

> **Android only.** Install-time component splitting relies on Play Feature Delivery. iOS has no equivalent — it uses App Thinning / on-demand resources. Assuming this works cross-platform is a known mistake.

## Requirements
- Build an **AAB** (`flutter build appbundle`), distributed via Google Play (feature modules need Play).
- **`--split-debug-info=<dir>` is required** when building with deferred components (and pair `--obfuscate` as usual).
- Some manual native wiring in `android/` is needed (the docs' deferred-components setup).

## Deferring Dart code

Import with `deferred as` and call `loadLibrary()` before first use:
```dart
import 'package:myapp/heavy_feature.dart' deferred as heavy;

Future<void> openHeavyFeature() async {
  await heavy.loadLibrary();        // downloads + loads the module on demand
  runHeavyFeature(heavy.buildScreen());
}
```
- The deferred library and its exclusive dependencies move out of the base module.
- `loadLibrary()` is a `Future` — show a loading state; handle failure (no network).
- Code reachable from the base app is **not** deferred; only code reachable solely through the deferred import is split out.

## Deferred assets

Assets used only by a deferred component can ship in that component:
```yaml
flutter:
  deferred-components:
    - name: heavyFeature
      libraries:
        - package:myapp/heavy_feature.dart
      assets:
        - assets/heavy/diagram.webp
```
Run `flutter build appbundle` and Flutter generates the loading units; validate against the generated `deferred_components` config it proposes.

## Build

```bash
flutter build appbundle \
  --obfuscate --split-debug-info=build/symbols
```
Then upload the AAB to Play; Play delivers feature modules on demand.

## ABI splits (different mechanism)

Per-architecture native code is handled by the **app bundle automatically** — Play generates per-device APKs containing only that device's ABI. You don't need manual ABI splits for Play; just ship the AAB.
```bash
# Only for non-Play distribution: split a universal APK per ABI
flutter build apk --split-per-abi
```

## When it's worth it
- Large, **optional** features used by a minority of users (heavy editor, AR, ML model).
- Big assets gated behind a feature.
Not worth it for code on the main path — that just adds a download stall. Measure the base-module delta with `--analyze-size` before and after.

## Gotchas
- iOS gets nothing from this — don't promise cross-platform size cuts here.
- Forgetting `--split-debug-info` fails the deferred build.
- A deferred feature still referenced from the base app won't actually split — check the loading-unit report.
