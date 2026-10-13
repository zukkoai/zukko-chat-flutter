# Runtime locale switching

Hold the chosen locale in app state (e.g. a Riverpod/ValueNotifier provider) and feed `MaterialApp.locale`. Passing `null` defers to the device locale.

```dart
final localeProvider = StateProvider<Locale?>((_) => null);

// In the app:
MaterialApp(
  locale: ref.watch(localeProvider),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
)

// To change language:
ref.read(localeProvider.notifier).state = const Locale('uz');
```

Persist the choice (e.g. `shared_preferences`) and restore on launch.

## Do / avoid

- Do keep all user-facing strings in ARB files; never hardcode literals.
- Do put `@`-descriptions and placeholder types in the template ARB only.
- Do format dates/numbers/currency through `intl` with the active locale.
- Do use `EdgeInsetsDirectional` / `AlignmentDirectional` for RTL safety.
- Avoid string concatenation for sentences — use placeholders/plurals/select.
- Avoid forgetting to re-run `flutter gen-l10n` after editing ARB keys.
