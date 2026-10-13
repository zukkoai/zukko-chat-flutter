# ThemeExtension: typed custom design tokens

`ColorScheme`/`TextTheme` cover Material's roles. For your **own** tokens — brand colors, spacing scale, corner radii, semantic colors like `success`/`warning` — define a typed `ThemeExtension`. It is theme-aware (light/dark), animates across theme changes via `lerp`, and is read with `Theme.of(context).extension<T>()`.

## Define the extension

Implement `copyWith` (selective overrides) and `lerp` (smooth animation between themes). Both are required.

```dart
// lib/core/theme/app_tokens.dart
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brand,
    required this.success,
    required this.warning,
    required this.spacingSm,
    required this.spacingMd,
    required this.radiusMd,
  });

  final Color brand;
  final Color success;
  final Color warning;
  final double spacingSm;
  final double spacingMd;
  final double radiusMd;

  @override
  AppTokens copyWith({
    Color? brand,
    Color? success,
    Color? warning,
    double? spacingSm,
    double? spacingMd,
    double? radiusMd,
  }) =>
      AppTokens(
        brand: brand ?? this.brand,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        spacingSm: spacingSm ?? this.spacingSm,
        spacingMd: spacingMd ?? this.spacingMd,
        radiusMd: radiusMd ?? this.radiusMd,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      brand: Color.lerp(brand, other.brand, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      spacingSm: lerpDouble(spacingSm, other.spacingSm, t)!,
      spacingMd: lerpDouble(spacingMd, other.spacingMd, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
    );
  }

  // light/dark instances
  static const light = AppTokens(
    brand: Color(0xFF6750A4),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFED6C02),
    spacingSm: 8,
    spacingMd: 16,
    radiusMd: 12,
  );

  static const dark = AppTokens(
    brand: Color(0xFFD0BCFF),
    success: Color(0xFF66BB6A),
    warning: Color(0xFFFFB74D),
    spacingSm: 8,
    spacingMd: 16,
    radiusMd: 12,
  );
}
```

## Register per brightness

```dart
ThemeData light() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
      extensions: const [AppTokens.light],
    );

ThemeData dark() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
      extensions: const [AppTokens.dark],
    );
```

## Access in widgets

```dart
final tokens = Theme.of(context).extension<AppTokens>()!;
Padding(
  padding: EdgeInsets.all(tokens.spacingMd),
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: tokens.success,
      borderRadius: BorderRadius.circular(tokens.radiusMd),
    ),
    child: child,
  ),
);
```

A tiny extension getter keeps call sites clean:

```dart
extension TokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
// usage: context.tokens.spacingMd
```
