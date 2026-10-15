import 'package:flutter/widgets.dart';

import '../../../theme/chatwoot_chat_theme.dart';

/// Smooth Silk: one cool pearl tone, bubbles a step lighter or darker than
/// the background, no borders or shadows, large even radii.
@immutable
class SmoothSilkTokens {
  final Brightness brightness;
  final Color background;
  final Color incomingBubble;
  final Color outgoingBubble;
  final Color media;
  final Color mediaIcon;
  final Color text;
  final Color mutedText;
  final Color accent;
  final Color onAccent;
  final Color composerFill;
  final Color composerButtonFill;
  final Color icon;
  final Color typingDot;
  final Color waveActive;
  final Color waveInactive;
  final Color playFill;
  final Color playIcon;
  final Color avatarFill;
  final Color avatarText;
  final Color error;

  static const double bubbleRadius = 24;
  static const double composerHeight = 54;

  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle caption;
  final TextStyle title;
  final TextStyle status;
  final TextStyle hint;

  const SmoothSilkTokens._({
    required this.brightness,
    required this.background,
    required this.incomingBubble,
    required this.outgoingBubble,
    required this.media,
    required this.mediaIcon,
    required this.text,
    required this.mutedText,
    required this.accent,
    required this.onAccent,
    required this.composerFill,
    required this.composerButtonFill,
    required this.icon,
    required this.typingDot,
    required this.waveActive,
    required this.waveInactive,
    required this.playFill,
    required this.playIcon,
    required this.avatarFill,
    required this.avatarText,
    required this.error,
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.title,
    required this.status,
    required this.hint,
  });

  factory SmoothSilkTokens.from(ZukkoChatTheme base) {
    final dark = base.isDark;
    Color pick(int light, int darkValue) => Color(dark ? darkValue : light);

    final accent = base.accentColor ?? pick(0xFF3A4A60, 0xFF9AADC6);
    final onAccent = base.accentColor == null
        ? pick(0xFFF8FAFC, 0xFF15181D)
        : ZukkoChatTheme.foregroundOn(accent);
    final text = pick(0xFF1F2733, 0xFFE6E9EE);
    final muted = pick(0xFF66717F, 0xFF8E98A6);

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

    return SmoothSilkTokens._(
      brightness: base.brightness,
      background: base.backgroundColor ?? pick(0xFFEDF0F4, 0xFF15181D),
      incomingBubble: pick(0xFFF8FAFC, 0xFF1F242B),
      outgoingBubble: pick(0xFFDCE2EA, 0xFF2A313B),
      media: pick(0xFFCBD3DE, 0xFF343C48),
      mediaIcon: pick(0xFF6A778A, 0xFF8794A6),
      text: text,
      mutedText: muted,
      accent: accent,
      onAccent: onAccent,
      composerFill: pick(0xFFF8FAFC, 0xFF1F242B),
      composerButtonFill: pick(0xFFEDF0F4, 0xFF2A313B),
      icon: pick(0xFF4C5869, 0xFFA9B3C0),
      typingDot: pick(0xFFA6AFBB, 0xFF6E7887),
      waveActive: base.accentColor ?? pick(0xFF3A4A60, 0xFFC9D2DE),
      waveInactive: pick(0xFFAEB8C6, 0xFF4A5463),
      playFill: pick(0xFFF8FAFC, 0xFF3A4350),
      playIcon: pick(0xFF2F3B4C, 0xFFE6E9EE),
      avatarFill: pick(0xFFF8FAFC, 0xFF1F242B),
      avatarText: pick(0xFF4A5A70, 0xFFB4C1D3),
      error: pick(0xFFB3261E, 0xFFF2B8B5),
      body: style(15, text, height: 1.45),
      bodyStrong: style(15, text, weight: FontWeight.w600, height: 1.3),
      caption: style(11.5, pick(0xFF7A8492, 0xFF7D8794)),
      title: style(16, text, weight: FontWeight.w600),
      status: style(12.5, muted),
      hint: style(15, pick(0xFF8A94A3, 0xFF7B8592)),
    );
  }
}

/// Manrope (the design font), unless the app forces one via
/// `ZukkoChatTheme.fontFamily`.
TextStyle _font(ZukkoChatTheme base, TextStyle style) {
  final family = base.fontFamily;
  return family != null
      ? style.copyWith(fontFamily: family)
      : style.copyWith(fontFamily: 'packages/zukko_chat_flutter/Manrope');
}
