import 'package:flutter/widgets.dart';

import '../../../theme/chatwoot_chat_theme.dart';

/// Minimal Clean: neutral white / near-black, agent text without bubbles,
/// a single ink accent.
@immutable
class MinimalCleanTokens {
  final Brightness brightness;
  final Color background;
  final Color text;
  final Color mutedText;
  final Color divider;
  final Color outgoingBubble;
  final Color media;
  final Color mediaIcon;
  final Color composerFill;
  final Color composerBorder;
  final Color icon;
  final Color accent;
  final Color onAccent;
  final Color typingDot;
  final Color waveInactive;
  final Color error;

  static const double bubbleRadius = 20;
  static const double composerRadius = 24;

  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle caption;
  final TextStyle title;
  final TextStyle status;
  final TextStyle hint;

  const MinimalCleanTokens._({
    required this.brightness,
    required this.background,
    required this.text,
    required this.mutedText,
    required this.divider,
    required this.outgoingBubble,
    required this.media,
    required this.mediaIcon,
    required this.composerFill,
    required this.composerBorder,
    required this.icon,
    required this.accent,
    required this.onAccent,
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

  factory MinimalCleanTokens.from(ChatwootChatTheme base) {
    final dark = base.isDark;
    Color pick(int light, int darkValue) => Color(dark ? darkValue : light);

    final accent = base.accentColor ?? pick(0xFF1A1A19, 0xFFECECEA);
    final onAccent = base.accentColor == null
        ? pick(0xFFFFFFFF, 0xFF121212)
        : ChatwootChatTheme.foregroundOn(accent);
    final text = pick(0xFF1A1A19, 0xFFECECEA);
    final muted = pick(0xFF6B6B67, 0xFF9A9A95);

    TextStyle style(
      double size,
      Color color, {
      FontWeight? weight,
      double? height,
    }) => _font(
      base,
      TextStyle(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
        height: height,
        color: color,
        letterSpacing: 0,
      ),
    );

    return MinimalCleanTokens._(
      brightness: base.brightness,
      background: base.backgroundColor ?? pick(0xFFFCFCFB, 0xFF121212),
      text: text,
      mutedText: muted,
      divider: pick(0xFFEFEFEC, 0xFF222221),
      outgoingBubble: pick(0xFFF0F0EE, 0xFF232322),
      media: pick(0xFFECECE9, 0xFF262625),
      mediaIcon: pick(0xFF7A7A75, 0xFF8F8F8A),
      composerFill: pick(0xFFFFFFFF, 0xFF1B1B1A),
      composerBorder: pick(0xFFE4E4E1, 0xFF2C2C2A),
      icon: pick(0xFF4A4A47, 0xFFBDBDB8),
      accent: accent,
      onAccent: onAccent,
      typingDot: pick(0xFF9A9A95, 0xFF8A8A85),
      waveInactive: pick(0xFFC4C4BF, 0xFF4A4A48),
      error: pick(0xFFB3261E, 0xFFF2B8B5),
      body: style(15.5, text, height: 1.55),
      bodyStrong: style(15, text, weight: FontWeight.w600, height: 1.3),
      caption: style(12, muted),
      title: style(16, text, weight: FontWeight.w600),
      status: style(12, muted),
      hint: style(15.5, pick(0xFF8E8E89, 0xFF7C7C78)),
    );
  }
}

/// Geist (the design font), unless the app forces one via
/// `ChatwootChatTheme.fontFamily`.
TextStyle _font(ChatwootChatTheme base, TextStyle style) {
  final family = base.fontFamily;
  return family != null
      ? style.copyWith(fontFamily: family)
      : style.copyWith(fontFamily: 'packages/chatwoot_sdk/Geist');
}
