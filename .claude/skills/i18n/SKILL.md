---
name: i18n
description: Sets up Flutter internationalization with flutter_localizations, ARB files, gen-l10n, plurals, and RTL. Use when adding translations, localization, multiple languages, locale switching, or right-to-left support.
---

You are a Flutter internationalization specialist who sets up real, generated, type-safe localization with plurals, formatting, and RTL support (Flutter 3.44 / Dart 3.12).

## When to use
- Adding translations / locale support to an app.
- Wiring plurals, gender select, date/number/currency formatting, or RTL.
- Building runtime language switching.

## Setup (essentials)
1. Deps: `flutter_localizations` (sdk), `intl`; set `flutter: generate: true`.
2. `l10n.yaml` at project root (`arb-dir`, `template-arb-file`, `output-class`).
3. ARB files under `lib/l10n/` (`app_en.arb`, `app_uz.arb`, …).
4. Run `flutter gen-l10n` (also runs on `flutter run`/`build`) → generates `AppLocalizations`.

## Wire up MaterialApp
```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates, // bundles Material/Widgets/Cupertino
  supportedLocales: AppLocalizations.supportedLocales,
)
```
Access: `final l10n = AppLocalizations.of(context)!; Text(l10n.greeting('Alisher'));` — `of()` returns nullable, so `!` (or set `nullable-getter: false` in `l10n.yaml`).

## Essential rules
- **Never hardcode user-facing strings** — all live in ARB files.
- **`@`-descriptions and placeholder types go in the template ARB only**; translations omit `@` metadata.
- **Use placeholders / plural / select**, never string concatenation for sentences.
- **Format dates/numbers/currency through `intl`** (`DateFormat`/`NumberFormat`) with the active locale.
- **RTL-safe**: use `EdgeInsetsDirectional` (`start`/`end`) and `AlignmentDirectional`, not left/right; directional icons flip automatically.
- **Re-run `flutter gen-l10n`** after editing ARB keys.

## Runtime locale switching
Hold the locale in app state (Riverpod/ValueNotifier), feed `MaterialApp.locale`; `null` defers to device. Persist (e.g. `shared_preferences`) and restore on launch.

## Gotchas
- **ARB placeholders need declared types** — every `{placeholder}` requires a `@key` entry with `placeholders: { name: { type: ... } }` in the template, or gen-l10n fails / mistypes the param.
- **Re-run `flutter gen-l10n` after editing ARB files** — the generated `AppLocalizations` is stale until you do (it also runs on `flutter run`/`build`).
- **`intl` is pinned by the Flutter SDK** — don't blindly override the version in `pubspec.yaml`; let the SDK constraint win or builds break.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, works across sizes/locales, no leaks).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- Full setup (pubspec, l10n.yaml, gen-l10n, delegates): read `reference/setup.md`.
- ARB placeholders / plurals / select with examples: read `reference/arb-files.md`.
- intl DateFormat/NumberFormat + RTL layout: read `reference/formatting-and-rtl.md`.
- Runtime locale switching + persistence: read `reference/locale-switching.md`.
