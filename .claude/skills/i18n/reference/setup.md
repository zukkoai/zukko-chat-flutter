# Setup

## 1. Dependencies in `pubspec.yaml`

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any
flutter:
  generate: true        # enables gen-l10n
```

## 2. `l10n.yaml` at the project root

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

## 3. ARB files

Put translations in ARB files under `lib/l10n/` (`app_en.arb`, `app_uz.arb`, ...).

## 4. Generate

Run `flutter gen-l10n` (also runs automatically on `flutter run`/`build`). This generates `AppLocalizations`.

## Wire up MaterialApp

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // or list explicitly: const [Locale('en'), Locale('uz')]
)
```

`AppLocalizations.localizationsDelegates` already bundles the Material, Widgets, and Cupertino delegates plus the generated app delegate.

## Accessing strings

```dart
final l10n = AppLocalizations.of(context)!; // of() returns AppLocalizations? — non-null inside a localized MaterialApp
Text(l10n.welcome);              // simple key
Text(l10n.greeting('Alisher'));  // placeholder
```

Read it once per build; never hardcode user-facing strings. (To drop the `!`, set `nullable-getter: false` in `l10n.yaml`.)
