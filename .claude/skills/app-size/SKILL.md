---
name: app-size
description: Shrinks Flutter app/bundle size — measures with --analyze-size and DevTools, --obfuscate + --split-debug-info, WebP assets, font subsetting, Android deferred components. Use for large APK/AAB/IPA, size budgets, or download-size cuts.
---

You are a Flutter app-size engineer who measures first, then cuts download size via code shrinking, asset compression, and (Android) deferred components (Flutter 3.44 / Dart 3.12).

## When to use
- The APK/AAB/IPA is too big, store flags download size, or you have a size budget to hit.
- Setting up obfuscation, font subsetting, ABI splits, or deferred-component loading.

## Detect first
Measure and inspect before optimizing — guesses waste effort:
- Run **`flutter build appbundle --analyze-size`** (or `--target-platform` for APK/iOS) and read the breakdown.
- Read `pubspec.yaml` `assets:`/`fonts:` — large PNG/JPG, full icon fonts, or whole font families?
- Read `pubspec.lock` for heavy deps (e.g. multiple image/video/ML libs) and unused locales.
- Check build flags: are `--obfuscate` and `--split-debug-info=<dir>` already paired? Are symbols archived per release?

## Core rules

| Do | Avoid (known AI mistakes) |
|---|---|
| **Measure** with `--analyze-size` + DevTools App Size tool first | Optimizing blind before any baseline |
| Pair **`--obfuscate` with `--split-debug-info=<dir>`** and back up symbols | `--obfuscate` alone, or treating it as encryption/security |
| WebP over PNG/JPG; ship resolution variants; compress | Huge full-res PNGs as the only variant |
| Let tree-shaking drop unused icons (static `IconData`) | Dynamic `IconData(codePoint)` — defeats icon tree-shaking |
| Subset/remove unused fonts & locales | Bundling whole icon fonts and every locale you don't ship |
| Deferred components for install-time code split (**Android only**) | Assuming deferred loading works on iOS |

**Measure first (the non-negotiable step).**
```bash
flutter build appbundle --analyze-size --target-platform android-arm64
flutter build ipa --analyze-size            # iOS
# Opens a tree map; also load build/<...>.json in DevTools > App Size tool to diff/inspect.
```
Optimize the biggest nodes (assets, native libs, Dart AOT), not whatever you guessed. See `reference/analyze-size.md`.

**Obfuscate correctly (and know what it is).**
```bash
flutter build appbundle --obfuscate --split-debug-info=build/symbols
```
- **Both flags are required together**; archive `build/symbols` **per release** or you can never symbolicate that version's crashes (cross-ref `observability`).
- **Obfuscation is NOT security or encryption** — it only renames symbols; code is still extractable. Top AI myth.
- It **breaks code that depends on names**: `runtimeType.toString()`, `T.toString()`, type-name switches, reflection-like lookups, enum `.name` used as a wire key. See `reference/obfuscation.md`.

**Cut assets & fonts.** WebP over PNG/JPG, provide `2.0x`/`3.0x` variants, compress, drop unused fonts and locales. Don't break icon tree-shaking with dynamic `IconData`. See `reference/assets-and-fonts.md`.

**Deferred components (Android).** Split install-time Dart + assets behind `loadLibrary()`; **Android-only** and requires `--split-debug-info`. ABI splits ship per-architecture via the app bundle. See `reference/deferred-components.md`.

## Gotchas
- **`--obfuscate` without `--split-debug-info` is a known AI mistake** — both are required, and you must archive `build/symbols` per release or crashes are unreadable.
- **"Obfuscation encrypts / secures the code" is a top AI myth** — it only renames symbols. Never put secrets in client code expecting obfuscation to hide them.
- **Obfuscation breaks name-dependent code** (known footgun): `runtimeType.toString()`, type-name comparisons, enum/`Type` names used as serialization keys, JSON code that keys off class names — these silently break in release.
- **Dynamic `IconData(0xe...)` defeats icon tree-shaking** (known AI mistake) → the whole font ships. Use const icon constants so `--tree-shake-icons` (default in release) can prune.
- **"Deferred components work on iOS" is a known AI mistake** — install-time component splitting is **Android-only**; iOS uses App Thinning/on-demand resources instead.
- **Use AAB, not APK, for Play** — Play generates per-device APKs (smaller downloads). A universal APK is the largest possible artifact.
- **`--analyze-size` numbers are uncompressed estimates** — actual store download is smaller; compare deltas, and check the store's reported download size.

## Common mistakes
- Optimizing before measuring → run `--analyze-size` + DevTools App Size first.
- `--obfuscate` alone → add `--split-debug-info=<dir>` and back up symbols.
- "Obfuscation secures my code" → it only renames; not encryption.
- Dynamic `IconData` → use const icons so tree-shaking prunes the font.
- Giant PNGs, all locales bundled → WebP + variants; trim unused fonts/locales.
- Expecting deferred components on iOS → Android only.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, works at large text scale / low memory).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- `--analyze-size`, DevTools App Size tool, reading the tree map: read `reference/analyze-size.md`.
- `--obfuscate` + `--split-debug-info`, symbol backup, not-encryption, what breaks: read `reference/obfuscation.md`.
- WebP, resolution variants, font subsetting, unused locales, icon tree-shaking: read `reference/assets-and-fonts.md`.
- Android deferred components, `loadLibrary()`, ABI splits: read `reference/deferred-components.md`.
