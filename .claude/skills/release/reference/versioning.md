# Versioning & obfuscation/symbols

## pubspec version maps to two numbers

```yaml
# pubspec.yaml
version: 1.2.3+45
```

- `1.2.3` → **versionName** (Android) / **CFBundleShortVersionString** (iOS) — the human version. Override with `--build-name`.
- `45` → **versionCode** (Android) / **CFBundleVersion** (iOS) — the integer build number. Override with `--build-number`.

```bash
flutter build appbundle --build-name=1.2.3 --build-number=45
```

CLI flags win over `pubspec.yaml`, which is how CI sets them without editing the file.

## The build number must strictly increase

- A **duplicate versionCode/build number gets rejected** by both stores, even if the version name is identical.
- You can ship `1.2.3+45` then `1.2.3+46` (same user-facing version, new build) — that's normal for re-submissions.

## CI auto-increment

Common pattern: derive the build number from the CI run number so it always increases.

```bash
flutter build appbundle --build-number=${CI_BUILD_NUMBER} --build-name=1.2.3
```

Or with fastlane: `increment_build_number` (iOS) / read+bump for Android. Never rely on a hand-edited `+N`.

## Obfuscation + symbols (release only)

`--obfuscate` renames Dart symbols. It is **useless and dangerous without** `--split-debug-info`, which extracts the debug symbols you need to read crashes.

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols
```

- **Both flags are required together** — `--obfuscate` alone has no separate symbol output and the analyzer/tool will warn.
- **Archive `build/symbols/` per release version** (CI artifact or storage). Without that version's symbols, its crash stack traces are permanently unreadable.
- To symbolicate a later crash:

```bash
flutter symbolize -i crash.txt -d build/symbols/app.android-arm64.symbols
```

## Per-platform symbol files

`--split-debug-info` writes one file per ABI/arch (`app.android-arm64.symbols`, `app.ios-arm64.symbols`, …). Keep the whole directory, not one file.

## Don't

- Don't reuse a build number → store rejection.
- Don't `--obfuscate` without `--split-debug-info` → unreadable crashes.
- Don't lose/overwrite the symbols for a shipped version → can't debug its crashes ever.
