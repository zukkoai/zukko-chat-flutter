# TextTheme: semantic roles and fonts

Style text by **role**, not by hand. Material 3 defines 15 semantic text styles across five groups. Reference them through `Theme.of(context).textTheme.<role>` instead of inline `TextStyle`.

## The role groups

| Group | Roles | Typical use |
|-------|-------|-------------|
| Display | `displayLarge`, `displayMedium`, `displaySmall` | Largest, hero/marketing text |
| Headline | `headlineLarge`, `headlineMedium`, `headlineSmall` | Section headers |
| Title | `titleLarge`, `titleMedium`, `titleSmall` | App bar titles, list/card titles |
| Body | `bodyLarge`, `bodyMedium`, `bodySmall` | Paragraphs, default content |
| Label | `labelLarge`, `labelMedium`, `labelSmall` | Buttons, captions, overlines |

```dart
// avoid: inline TextStyle in every widget
Text('Welcome', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700));

// do: a semantic role from the theme
Text('Welcome', style: Theme.of(context).textTheme.headlineMedium);
```

## Customizing the TextTheme centrally

Adjust roles once in `ThemeData`; every widget that uses the role updates.

```dart
ThemeData(
  colorScheme: scheme,
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
    bodyMedium: TextStyle(fontSize: 16, height: 1.4),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  ),
);
```

Tweak rather than replace with `.apply` / `.copyWith` (preserves the other roles):

```dart
final base = ThemeData(colorScheme: scheme);
final textTheme = base.textTheme.apply(
  bodyColor: scheme.onSurface,
  displayColor: scheme.onSurface,
);
```

## Applying a custom font

With `google_fonts`, build the whole theme's text from one family so all roles stay consistent:

```dart
ThemeData(
  colorScheme: scheme,
  textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: scheme.brightness).textTheme),
);
```

Or bundle a font via `pubspec.yaml` `fonts:` and set `fontFamily`/per-role `TextStyle(fontFamily: ...)`. Keep all of this in `lib/core/theme/` — widgets never name fonts directly.
