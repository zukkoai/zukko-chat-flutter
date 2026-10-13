# Analyzing app size

Always measure before and after a change. Two tools: the `--analyze-size` CLI flag (quick tree map) and the DevTools **App Size** tool (deep, diffable).

## --analyze-size

```bash
# Android App Bundle (recommended artifact for Play)
flutter build appbundle --analyze-size --target-platform android-arm64

# APK
flutter build apk --analyze-size --target-platform android-arm64

# iOS
flutter build ipa --analyze-size
```
- Prints a breakdown by category (Dart AOT, native libraries, assets, fonts, ...) and writes a JSON snapshot under `~/.flutter-devtools/` (path printed at the end).
- `--target-platform` matters: per-ABI numbers differ. `android-arm64` is the dominant device class.
- Numbers are **uncompressed estimates**, not the final store download — use them for relative comparison, not as the literal download size.

## DevTools App Size tool

```bash
flutter pub global activate devtools   # if not already available
dart devtools                          # open the App Size tab
```
- Load the JSON snapshot from `--analyze-size` into the **App Size** tool.
- **Analysis tab**: tree map of where bytes go — drill into packages, assets, and individual symbols.
- **Diff tab**: load two snapshots (before/after) to verify a change actually shrank the build and didn't regress elsewhere.

## Reading the report — what to attack

| Big node | Typical cause | Fix |
|---|---|---|
| `assets/` | Uncompressed PNG/JPG, no variants | WebP + resolution variants, compress |
| Fonts | Whole icon font or font family bundled | Subset / remove unused (`assets-and-fonts.md`) |
| Dart AOT (`libapp.so`) | Large dependency graph, unused code | Drop heavy deps; tree-shaking; deferred components |
| Native libs (`.so`) | Multiple ABIs in one APK | Ship an **AAB** (per-device split) |
| Locales | Every locale bundled | Limit shipped locales |

## Workflow

1. Baseline: `flutter build appbundle --analyze-size` → record total + biggest nodes.
2. Change one thing (compress assets / subset fonts / drop a dep).
3. Re-measure; diff in DevTools App Size tool.
4. Keep the change only if the diff shows a real win.

## Notes
- Build in **release** mode for realistic numbers; debug builds carry extra overhead.
- For Play, compare against the store's **download size** in the Play Console (it reflects compression + device targeting), not the raw artifact size.
- iOS: App Store applies App Thinning; the user's download is smaller than the universal IPA.
