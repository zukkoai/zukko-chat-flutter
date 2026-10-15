import 'package:flutter/widgets.dart';

import '../../../theme/chatwoot_chat_theme.dart';

/// Thread Feed: white / graphite rows, deep green accent, 10-12 px corners.
@immutable
class ThreadFeedTokens {
  final Brightness brightness;
  final Color background;
  final Color text;
  final Color mutedText;
  final Color divider;
  final Color accent;
  final Color onAccent;
  final Color agentAvatarFill;
  final Color agentAvatarText;
  final Color userAvatarFill;
  final Color userAvatarText;
  final Color cardFill;
  final Color cardBorder;
  final Color media;
  final Color mediaIcon;
  final Color fieldFill;
  final Color icon;
  final Color micFill;
  final Color micIcon;
  final Color online;
  final Color link;
  final Color waveInactive;
  final Color typingDot;
  final Color error;

  static const double radius = 12;
  static const double avatarSize = 34;
  static const double avatarGap = 12;

  final TextStyle body;
  final TextStyle name;
  final TextStyle bodyStrong;
  final TextStyle caption;
  final TextStyle title;
  final TextStyle status;
  final TextStyle hint;

  const ThreadFeedTokens._({
    required this.brightness,
    required this.background,
    required this.text,
    required this.mutedText,
    required this.divider,
    required this.accent,
    required this.onAccent,
    required this.agentAvatarFill,
    required this.agentAvatarText,
    required this.userAvatarFill,
    required this.userAvatarText,
    required this.cardFill,
    required this.cardBorder,
    required this.media,
    required this.mediaIcon,
    required this.fieldFill,
    required this.icon,
    required this.micFill,
    required this.micIcon,
    required this.online,
    required this.link,
    required this.waveInactive,
    required this.typingDot,
    required this.error,
    required this.body,
    required this.name,
    required this.bodyStrong,
    required this.caption,
    required this.title,
    required this.status,
    required this.hint,
  });

  factory ThreadFeedTokens.from(ChatwootChatTheme base) {
    final dark = base.isDark;
    Color pick(int light, int darkValue) => Color(dark ? darkValue : light);

    final override = base.accentColor;
    final accent = override ?? pick(0xFF0F766E, 0xFF4FB7A9);
    final onAccent = override == null
        ? pick(0xFFFFFFFF, 0xFF0E1211)
        : ChatwootChatTheme.foregroundOn(accent);
    final text = pick(0xFF1B1D1C, 0xFFE7E9E8);
    final muted = pick(0xFF6A6F6C, 0xFF8E9591);

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

    return ThreadFeedTokens._(
      brightness: base.brightness,
      background: base.backgroundColor ?? pick(0xFFFFFFFF, 0xFF111312),
      text: text,
      mutedText: muted,
      divider: pick(0xFFECEDEC, 0xFF222624),
      accent: accent,
      onAccent: onAccent,
      agentAvatarFill: override ?? pick(0xFF0F766E, 0xFF1E4A45),
      agentAvatarText: override == null
          ? pick(0xFFFFFFFF, 0xFFA8E2D9)
          : ChatwootChatTheme.foregroundOn(override),
      userAvatarFill: pick(0xFFE7EAE8, 0xFF2A2E2C),
      userAvatarText: pick(0xFF3D433F, 0xFFC9CFCB),
      cardFill: pick(0xFFFFFFFF, 0xFF161918),
      cardBorder: pick(0xFFE4E6E5, 0xFF2A2F2D),
      media: pick(0xFFDCE3DF, 0xFF232A27),
      mediaIcon: pick(0xFF6F7A74, 0xFF7D8781),
      fieldFill: pick(0xFFF3F5F4, 0xFF1A1D1C),
      icon: pick(0xFF4A4F4C, 0xFFB3BAB6),
      micFill: pick(0xFFE1EEEC, 0xFF1E3532),
      micIcon: override ?? pick(0xFF0F766E, 0xFF6CC8BB),
      online: pick(0xFF2F9E6E, 0xFF4CC08A),
      link: override ?? pick(0xFF0F766E, 0xFF6CC8BB),
      waveInactive: pick(0xFFBCC6C1, 0xFF3A423F),
      typingDot: pick(0xFF9AA19D, 0xFF5E6662),
      error: pick(0xFFB3261E, 0xFFF2B8B5),
      body: style(15, text, height: 1.5),
      name: style(14, text, weight: FontWeight.w600),
      bodyStrong: style(14, text, weight: FontWeight.w600, height: 1.3),
      caption: style(12, muted),
      title: style(16, text, weight: FontWeight.w600),
      status: style(12.5, muted),
      hint: style(15, pick(0xFF868B88, 0xFF7D8481)),
    );
  }
}

/// Onest (the design font), unless the app forces one via
/// `ChatwootChatTheme.fontFamily`.
TextStyle _font(ChatwootChatTheme base, TextStyle style) {
  final family = base.fontFamily;
  return family != null
      ? style.copyWith(fontFamily: family)
      : style.copyWith(fontFamily: 'packages/chatwoot_sdk/Onest');
}
