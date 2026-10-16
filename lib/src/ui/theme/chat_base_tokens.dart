import 'package:flutter/widgets.dart';

import 'zukko_chat_theme.dart';

/// Sizes of the shared text roles of a style (all w400 except the strong
/// body and the title, w600).
@immutable
class ChatTypeScale {
  final double body;
  final double bodyHeight;
  final double strong;
  final double strongHeight;
  final double caption;
  final double title;
  final double status;
  final double hint;

  const ChatTypeScale({
    required this.body,
    required this.bodyHeight,
    required this.caption,
    required this.status,
    this.strong = 15,
    this.strongHeight = 1.3,
    this.title = 16,
    double? hint,
  }) : hint = hint ?? body;
}

/// The palette and text roles every chat style has; a style's tokens extend
/// it with their own colors. Built from the style's [Tone]s and the app's
/// [ZukkoChatTheme] (brightness, font, accent and background overrides).
@immutable
class ChatBaseTokens {
  final Brightness brightness;
  final Color background;
  final Color text;
  final Color mutedText;
  final Color accent;
  final Color onAccent;
  final Color media;
  final Color mediaIcon;
  final Color icon;
  final Color typingDot;
  final Color waveInactive;
  final Color error;

  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle caption;
  final TextStyle title;
  final TextStyle status;
  final TextStyle hint;

  const ChatBaseTokens._all({
    required this.brightness,
    required this.background,
    required this.text,
    required this.mutedText,
    required this.accent,
    required this.onAccent,
    required this.media,
    required this.mediaIcon,
    required this.icon,
    required this.typingDot,
    required this.waveInactive,
    required this.error,
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.title,
    required this.status,
    required this.hint,
  });

  /// For subclasses: takes everything over from [base].
  ChatBaseTokens.from(ChatBaseTokens base)
    : this._all(
        brightness: base.brightness,
        background: base.background,
        text: base.text,
        mutedText: base.mutedText,
        accent: base.accent,
        onAccent: base.onAccent,
        media: base.media,
        mediaIcon: base.mediaIcon,
        icon: base.icon,
        typingDot: base.typingDot,
        waveInactive: base.waveInactive,
        error: base.error,
        body: base.body,
        bodyStrong: base.bodyStrong,
        caption: base.caption,
        title: base.title,
        status: base.status,
        hint: base.hint,
      );

  /// [captionColor] defaults to [muted].
  factory ChatBaseTokens.resolve(
    ZukkoChatTheme theme, {
    required String family,
    required ChatTypeScale scale,
    required Tone background,
    required Tone text,
    required Tone muted,
    required Tone accent,
    required Tone onAccent,
    required Tone media,
    required Tone mediaIcon,
    required Tone icon,
    required Tone typingDot,
    required Tone waveInactive,
    required Tone hint,
    Tone? captionColor,
  }) {
    final textColor = theme.tone(text);
    final mutedColor = theme.tone(muted);

    TextStyle style(
      double size,
      Color color, {
      FontWeight weight = FontWeight.w400,
      double? height,
    }) => theme.font(
      family,
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color,
        letterSpacing: 0,
      ),
    );

    return ChatBaseTokens._all(
      brightness: theme.brightness,
      background: theme.backgroundColor ?? theme.tone(background),
      text: textColor,
      mutedText: mutedColor,
      accent: theme.accentOr(accent),
      onAccent: theme.onAccentOr(onAccent),
      media: theme.tone(media),
      mediaIcon: theme.tone(mediaIcon),
      icon: theme.tone(icon),
      typingDot: theme.tone(typingDot),
      waveInactive: theme.tone(waveInactive),
      error: theme.pick(0xFFB3261E, 0xFFF2B8B5),
      body: style(scale.body, textColor, height: scale.bodyHeight),
      bodyStrong: style(
        scale.strong,
        textColor,
        weight: FontWeight.w600,
        height: scale.strongHeight,
      ),
      caption: style(
        scale.caption,
        captionColor == null ? mutedColor : theme.tone(captionColor),
      ),
      title: style(scale.title, textColor, weight: FontWeight.w600),
      status: style(scale.status, mutedColor),
      hint: style(scale.hint, theme.tone(hint)),
    );
  }

  /// [text] laid over [background] at [alpha]: a surface a step away from
  /// the background, for derived fills when the app overrides it.
  static Color tint(Color background, Color text, double alpha) =>
      Color.alphaBlend(text.withValues(alpha: alpha), background);
}
