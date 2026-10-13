# Deprecated → current APIs (stale forms AI commonly emits)

Most of these have a `dart fix` quick-fix — run `dart fix --apply` first, then verify with `flutter analyze`. The table is the canonical stale→current mapping for hand edits.

## Colors & opacity
| Stale (AI mistake) | Current |
|---|---|
| `color.withOpacity(0.5)` | `color.withValues(alpha: 0.5)` |
| `Color.fromRGBO(...)` for alpha tweaks | `color.withValues(alpha: x)` |
| `color.value` (32-bit int) | component accessors `.a` `.r` `.g` `.b` (double 0–1) |
| `color.red` / `.green` / `.blue` (0–255 int) | `(color.r * 255).round()` etc., or work in `.r/.g/.b` doubles |
| `color.alpha` (0–255 int) | `color.a` (double 0–1) |
| `color.opacity` (double 0–1) | `color.a` (double 0–1) |

`withOpacity` loses precision (8-bit) and is **deprecated in Flutter 3.27** (wide-gamut color); `withValues` keeps full-precision channels. Build a color from 0–1 doubles with `Color.from(alpha: a, red: r, green: g, blue: b)`.

## Material → Widget state
| Stale (AI mistake) | Current |
|---|---|
| `MaterialStateProperty.all(x)` | `WidgetStateProperty.all(x)` |
| `MaterialStateProperty.resolveWith(...)` | `WidgetStateProperty.resolveWith(...)` |
| `MaterialState.pressed` / `.hovered` / ... | `WidgetState.pressed` / `.hovered` / ... |
| `MaterialStatesController` | `WidgetStatesController` |
| `MaterialStateColor` / `MaterialStateMouseCursor` | `WidgetStateColor` / `WidgetStateMouseCursor` |

The classes moved out of Material so they work in non-Material widgets; the `Material*` names are deprecated aliases.

## Text scaling
| Stale (AI mistake) | Current |
|---|---|
| `textScaleFactor: 1.5` (double) | `textScaler: TextScaler.linear(1.5)` |
| `MediaQuery.textScaleFactorOf(context)` | `MediaQuery.textScalerOf(context)` |
| `MediaQuery.of(context).textScaleFactor` | `MediaQuery.textScalerOf(context)` |

`TextScaler` supports non-linear scaling; the flat `double` factor is **deprecated since Flutter 3.16**.

## Theme surfaces
| Stale (AI mistake) | Current |
|---|---|
| `ColorScheme.background` | `ColorScheme.surface` |
| `ColorScheme.onBackground` | `ColorScheme.onSurface` |
| `ThemeData(backgroundColor: ...)` | use `ColorScheme.surface` / `Scaffold(backgroundColor:)` |
| `ColorScheme.surfaceVariant` | `ColorScheme.surfaceContainerHighest` |

`background`/`onBackground` were removed from `ColorScheme`; map them onto the surface roles.

## Misc commonly-stale forms
| Stale (AI mistake) | Current |
|---|---|
| `flutter packages get` | `flutter pub get` |
| `dart migrate` | `dart fix --apply` (and version pin via fvm) |
| `RaisedButton` / `FlatButton` / `OutlineButton` | `ElevatedButton` / `TextButton` / `OutlinedButton` |
| `Scaffold.of(context).showSnackBar` | `ScaffoldMessenger.of(context).showSnackBar` |
| `WillPopScope` | `PopScope` |
| `accentColor` (ThemeData) | `ColorScheme.secondary` |
| `Slider(year2023: ...)` left implicit | new slider visuals are default; pass `year2023: false` only if you must opt out |

## Build config / Gradle
| Stale (AI mistake) | Current |
|---|---|
| imperative `apply plugin:` of Flutter's Gradle plugins | declarative `plugins { }` DSL (Flutter plugin block) |

Kotlin DSL (`build.gradle.kts`) is the **default for NEW projects since Flutter 3.29** — but Groovy `.gradle` is **not deprecated** and existing projects need not migrate. What IS deprecated is the **imperative `apply` of Flutter's Gradle plugins → the declarative `plugins {}` DSL**. Migrating Groovy → Kotlin DSL is optional, not required.

## Package-level deprecations (cross-links)
migrations is the single source of truth; the rewrites themselves live in the owning skill.
| Stale (AI mistake) | Current |
|---|---|
| freezed `.when(...)` / `.map(...)` on unions | Dart 3 pattern matching (`switch` / `if-case`) — see `data-model` |
| Riverpod legacy `StateProvider` / `StateNotifierProvider` / `ChangeNotifierProvider` | import `package:flutter_riverpod/legacy.dart` — see `state-management` |
| `AsyncValue.valueOrNull` | `AsyncValue.value` (now nullable) — see `state-management` |

After any sweep: `dart fix --apply` → `flutter analyze` → run tests. Anything `analyze` still flags has no auto-fix and needs a manual edit guided by the breaking-changes doc.
