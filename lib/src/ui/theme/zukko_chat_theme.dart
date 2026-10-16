import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The style-independent base of the chat look, as a [ThemeExtension].
///
/// Every chat style (`ZukkoChatOptions.style`) derives its own tokens from
/// this: the style owns its palette and font, this theme decides brightness
/// and the few values an app may want to force on every style.
///
/// Resolution (see [resolve]): `ZukkoChatOptions.theme`, else one
/// registered in `ThemeData.extensions`, else one derived from the ambient
/// [ThemeData] (so dark mode follows the app).
/// A (light, dark) pair of ARGB values.
typedef Tone = (int light, int dark);

@immutable
class ZukkoChatTheme extends ThemeExtension<ZukkoChatTheme> {
  /// Light or dark variant of the style.
  final Brightness brightness;

  /// Forces one font family on all chat text; null uses the style's own
  /// design font (Smooth Silk: Manrope, Minimal Clean: Geist, Thread Feed:
  /// Onest, bundled with the package).
  final String? fontFamily;

  /// Overrides the style's accent (send button, links, brand link).
  final Color? accentColor;

  /// Overrides the style's chat background.
  final Color? backgroundColor;

  /// Gap between the screen edge and the messages / composer.
  final double horizontalPadding;

  const ZukkoChatTheme({
    required this.brightness,
    this.fontFamily,
    this.accentColor,
    this.backgroundColor,
    this.horizontalPadding = 16,
  });

  /// Base theme with the brightness of [scheme]; the style keeps its own
  /// palette. Set [accentColor] to brand it with e.g. `scheme.primary`.
  factory ZukkoChatTheme.fromColorScheme(ColorScheme scheme) =>
      ZukkoChatTheme(brightness: scheme.brightness);

  /// Base theme with the brightness of [theme]; fonts and colors stay the
  /// style's own.
  factory ZukkoChatTheme.fromThemeData(ThemeData theme) =>
      ZukkoChatTheme(brightness: theme.brightness);

  /// [override] if given, else the theme registered in [ThemeData.extensions],
  /// else one derived from the ambient theme.
  static ZukkoChatTheme resolve(
    BuildContext context, [
    ZukkoChatTheme? override,
  ]) {
    final theme = Theme.of(context);
    return override ??
        theme.extension<ZukkoChatTheme>() ??
        ZukkoChatTheme.fromThemeData(theme);
  }

  bool get isDark => brightness == Brightness.dark;

  /// The light or dark ARGB value, by [brightness].
  Color pick(int light, int dark) => Color(isDark ? dark : light);

  /// [pick] for a [Tone].
  Color tone(Tone t) => pick(t.$1, t.$2);

  /// The app's [accentColor], else the style's own [fallback].
  Color accentOr(Tone fallback) => accentColor ?? tone(fallback);

  /// Readable color on [accentOr]: derived from the app's accent, else the
  /// style's own [fallback].
  Color onAccentOr(Tone fallback) {
    final accent = accentColor;
    return accent == null ? tone(fallback) : foregroundOn(accent);
  }

  /// [style] in the style's design font [designFamily] (bundled with the
  /// package), unless the app forces one via [fontFamily].
  TextStyle font(String designFamily, TextStyle style) => style.copyWith(
    fontFamily: fontFamily ?? 'packages/zukko_chat_flutter/$designFamily',
  );

  /// Readable foreground (text, icon) on [background].
  static Color foregroundOn(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF111111);

  @override
  ZukkoChatTheme copyWith({
    Brightness? brightness,
    String? fontFamily,
    Color? accentColor,
    Color? backgroundColor,
    double? horizontalPadding,
  }) => ZukkoChatTheme(
    brightness: brightness ?? this.brightness,
    fontFamily: fontFamily ?? this.fontFamily,
    accentColor: accentColor ?? this.accentColor,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    horizontalPadding: horizontalPadding ?? this.horizontalPadding,
  );

  @override
  ZukkoChatTheme lerp(ThemeExtension<ZukkoChatTheme>? other, double t) {
    if (other is! ZukkoChatTheme) return this;
    return ZukkoChatTheme(
      brightness: t < 0.5 ? brightness : other.brightness,
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
      accentColor: Color.lerp(accentColor, other.accentColor, t),
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      horizontalPadding: lerpDouble(
        horizontalPadding,
        other.horizontalPadding,
        t,
      )!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ZukkoChatTheme &&
      other.brightness == brightness &&
      other.fontFamily == fontFamily &&
      other.accentColor == accentColor &&
      other.backgroundColor == backgroundColor &&
      other.horizontalPadding == horizontalPadding;

  @override
  int get hashCode => Object.hash(
    brightness,
    fontFamily,
    accentColor,
    backgroundColor,
    horizontalPadding,
  );
}
