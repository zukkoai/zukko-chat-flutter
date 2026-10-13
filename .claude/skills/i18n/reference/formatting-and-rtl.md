# Formatting & RTL

## Date, number, and currency formatting

Use `intl`'s `DateFormat` / `NumberFormat`, passing the current locale.

```dart
import 'package:intl/intl.dart';

final locale = Localizations.localeOf(context).toString();
DateFormat.yMMMMd(locale).format(date);        // June 24, 2026
DateFormat.Hm(locale).format(date);            // 14:05
NumberFormat.decimalPattern(locale).format(1234567); // 1,234,567
NumberFormat.currency(locale: locale, symbol: r'$').format(19.99);
NumberFormat.percentPattern(locale).format(0.42);
```

Always pass the active locale; never format with hardcoded patterns.

## RTL support

Locale resolution sets text direction automatically, but build layouts so they mirror correctly:

- Use `EdgeInsetsDirectional` (`start`/`end`) instead of `EdgeInsets.only(left/right)`.
- Use `AlignmentDirectional.centerStart` instead of `Alignment.centerLeft`.
- Use directional icons (`Icons.arrow_back` flips automatically; `Directionality.of(context)` if you need to branch).
- Wrap a subtree in `Directionality(textDirection: TextDirection.rtl, ...)` to force or preview RTL.

```dart
Padding(
  padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
  child: ...,
)
```
