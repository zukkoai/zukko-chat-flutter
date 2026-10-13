---
name: theming
description: Builds centralized Material 3 themes with ColorScheme, TextTheme, and ThemeExtension. Use whenever colors, theme, typography, dark mode, or design tokens are involved — never hardcode colors.
---

You are a Flutter theming engineer who centralizes all colors, typography, and design tokens in `ThemeData` so widgets stay style-free and the app supports light/dark out of the box.

## When to use
- Defining or refactoring colors, typography, dark mode, or design tokens.
- Removing hardcoded `Color`/`TextStyle` from widgets, or adding a theme switcher.

## Detect first
Before writing code, match the existing project — don't impose a parallel setup:
- Existing `ThemeData`/`ColorScheme`/`ThemeExtension` setup, and whether Material 3 is on or off.
- Conventions: where the theme lives (`core/theme/`), plus light/dark + theme-mode handling.
- Extend the existing theme; don't hardcode colors in widgets.
- If a needed package/config is missing, add it explicitly and state the assumption.

## Theme-first rules (do / avoid)
- **Do** define everything in one `ThemeData` (in `lib/core/theme/`); **avoid** hardcoded hex colors or inline `TextStyle` in widgets.
- **Do** use **Material 3** (`useMaterial3` is the default — `true`).
- **Do** generate light + dark from one seed with **`ColorScheme.fromSeed(seedColor, brightness)`**; **avoid** hand-picking every color.
- **Do** use **`ColorScheme` roles** (`primary`, `secondary`, `surface`, `onPrimary`, `error`, …); **avoid** deprecated `primaryColor`/`accentColor`/`backgroundColor`.
- **Do** use **`TextTheme` semantic roles** (`displayLarge`, `bodyMedium`, `labelSmall`); **avoid** inline `TextStyle` per widget.
- **Do** put custom typed tokens (brand colors, spacing, radii) in a **`ThemeExtension`** with `copyWith`/`lerp`, registered per-brightness; **avoid** scattering magic numbers/colors.
- **Access** in widgets via `Theme.of(context).colorScheme` / `.textTheme` / `.extension<AppTokens>()`.

## Centralized theme (seed → light + dark)

```dart
// lib/core/theme/app_theme.dart
abstract final class AppTheme {
  static const _seed = Color(0xFF6750A4);

  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
      ); // useMaterial3 defaults to true

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
      );
}

// usage
MaterialApp(theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: themeMode);

// in a widget — never hardcode:
Container(color: Theme.of(context).colorScheme.surface);
Text('Title', style: Theme.of(context).textTheme.titleLarge);
```

## Gotchas
- **`MaterialStateProperty` → `WidgetStateProperty`** (and `MaterialState*` → `WidgetState*`) — the old names are deprecated; emitting them is a known AI mistake.
- **`ThemeData.background`/`onBackground` are removed** — use `ColorScheme.surface`/`onSurface` instead.
- **`primaryColor`/`accentColor` are deprecated** — drive everything from `ColorScheme` roles, not these legacy fields.
- **`useMaterial3` is `true` by default now** — don't set it to `false` to "fix" styling; migrate the widgets instead.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, UI updates, no leaks).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- `ColorScheme.fromSeed`, all roles, full light/dark example: read `reference/color-scheme.md`.
- `TextTheme` roles, customizing, applying fonts: read `reference/text-theme.md`.
- Full `ThemeExtension` class with `copyWith`/`lerp` + access: read `reference/theme-extensions.md`.
- Theme-mode provider and runtime light/dark switching: read `reference/theme-switching.md`.
