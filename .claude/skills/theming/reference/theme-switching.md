# Theme switching: light/dark at runtime

Drive `MaterialApp.themeMode` from a small state holder so the user can choose Light / Dark / System and the choice can persist.

## ThemeMode provider (Riverpod)

```dart
// lib/core/theme/theme_mode_provider.dart
@riverpod
class AppThemeMode extends _$AppThemeMode {
  @override
  ThemeMode build() => ThemeMode.system;   // optionally load persisted value here

  void set(ThemeMode mode) => state = mode;
  void toggle() => state =
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}
```

```dart
// app root
class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,            // system / light / dark
      home: const HomePage(),
    );
  }
}
```

`themeMode: ThemeMode.system` follows the OS setting; `light`/`dark` force a mode. Because both `theme` and `darkTheme` are supplied, switching animates (and `ThemeExtension.lerp` interpolates custom tokens).

## With provider / ChangeNotifier

```dart
class ThemeModeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  void set(ThemeMode m) { _mode = m; notifyListeners(); }
}
// MaterialApp: themeMode: context.watch<ThemeModeController>().mode
```

## Persisting the choice

Load the saved mode on startup and write on change (e.g. `shared_preferences`):

```dart
// read in build()/init; on change:
await prefs.setString('themeMode', mode.name);
// restore: ThemeMode.values.byName(prefs.getString('themeMode') ?? 'system')
```

## A theme toggle widget

```dart
SegmentedButton<ThemeMode>(
  segments: const [
    ButtonSegment(value: ThemeMode.system, label: Text('System')),
    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
  ],
  selected: {ref.watch(appThemeModeProvider)},
  onSelectionChanged: (s) => ref.read(appThemeModeProvider.notifier).set(s.first),
);
```
