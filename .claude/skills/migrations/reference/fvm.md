# fvm — pin the Flutter SDK per project

Flutter Version Management installs multiple Flutter SDKs side by side and pins one per project, so an upgrade never leaks into other projects or CI.

## Why not `flutter upgrade`
`flutter upgrade` mutates the single global SDK on the machine/runner. Every other project and every CI job now uses the new version — a silent way to break unrelated builds. Pin instead.

## Install
```bash
dart pub global activate fvm        # or: brew tap leoafarias/fvm && brew install fvm
fvm --version
```

## Pin a version
```bash
fvm install 3.44.0      # downloads that SDK into the fvm cache
fvm use 3.44.0          # writes .fvmrc and links .fvm/flutter_sdk
```
This creates `.fvmrc`:
```json
{ "flutter": "3.44.0" }
```
**Commit `.fvmrc`.** Gitignore the symlink/cache: add `.fvm/` to `.gitignore` (keep `.fvmrc` tracked).

## Run tools through fvm
```bash
fvm flutter pub get
fvm flutter analyze
fvm dart fix --apply
```
A bare `flutter` still uses the global SDK — prefix with `fvm` (or alias it) so the pinned version is used.

## IDE integration
- **VS Code** — point the SDK at the pinned path in `.vscode/settings.json`:
  ```json
  { "dart.flutterSdkPath": ".fvm/flutter_sdk" }
  ```
- **Android Studio / IntelliJ** — set the Flutter SDK path to the project's `.fvm/flutter_sdk`.

## CI integration
- `subosito/flutter-action` reads the version directly; pass it explicitly so CI matches `.fvmrc`:
  ```yaml
  - uses: subosito/flutter-action@v2
    with: { flutter-version: 3.44.0, channel: stable, cache: true }
  ```
- Or install fvm in CI and run `fvm install && fvm flutter ...`. Either way, the version in CI must equal `.fvmrc` — drift causes "works locally, fails in CI".

## Switching versions for a migration
```bash
fvm install 3.45.0
fvm use 3.45.0          # rewrites .fvmrc
fvm flutter pub get
fvm flutter analyze
```
Roll back by `fvm use <old>` — the old SDK is still cached, so reverting is instant.
