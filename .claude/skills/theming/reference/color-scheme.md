# ColorScheme: fromSeed, roles, light/dark

## Generate a full scheme from one seed

`ColorScheme.fromSeed` derives a complete, accessible, tonally-balanced palette (all roles) from a single seed color, per brightness. This is the Material 3 way — never hand-assign every color.

```dart
final lightScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF6750A4),
  brightness: Brightness.light,
);
final darkScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF6750A4),
  brightness: Brightness.dark,
);
```

Override individual roles only when design demands it:

```dart
ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light)
    .copyWith(error: const Color(0xFFB3261E));
```

## ColorScheme roles (use these, not deprecated props)

| Role | Use for | "On" pair |
|------|---------|-----------|
| `primary` | Main brand actions (FAB, primary button) | `onPrimary` |
| `secondary` | Less-prominent accents, chips | `onSecondary` |
| `tertiary` | Contrasting accents | `onTertiary` |
| `surface` | Cards, sheets, backgrounds | `onSurface` |
| `surfaceContainerHighest` … `Lowest` | Elevation tints / layered surfaces | `onSurface` |
| `error` | Error states | `onError` |
| `outline` / `outlineVariant` | Borders, dividers | — |
| `inverseSurface` / `onInverseSurface` | Snackbars, inverse regions | — |

Deprecated — **do not use**: `primaryColor`, `accentColor`, `backgroundColor`, `ColorScheme.background`/`onBackground` (folded into `surface`). Read colors via `Theme.of(context).colorScheme.<role>`.

## Full light + dark theme

```dart
// lib/core/theme/app_theme.dart
abstract final class AppTheme {
  static const _seed = Color(0xFF6750A4);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,          // useMaterial3 defaults to true
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      // component themes (buttons, inputs, cards) also read from `scheme`
    );
  }
}

// app entry
MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: ThemeMode.system,   // or a value from a theme-mode provider
  home: const HomePage(),
);
```

## Using it in widgets

```dart
final scheme = Theme.of(context).colorScheme;
FilledButton(
  style: FilledButton.styleFrom(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary),
  onPressed: () {},
  child: const Text('Continue'),
);
ColoredBox(color: scheme.surfaceContainerHighest, child: child);
```
