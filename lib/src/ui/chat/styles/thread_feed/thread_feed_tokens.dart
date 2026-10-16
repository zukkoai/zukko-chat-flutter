import 'package:flutter/widgets.dart';

import '../../../theme/chat_base_tokens.dart';
import '../../../theme/zukko_chat_theme.dart';

/// Thread Feed: white / graphite rows, deep green accent, 10-12 px corners.
@immutable
class ThreadFeedTokens extends ChatBaseTokens {
  final Color divider;
  final Color agentAvatarFill;
  final Color agentAvatarText;
  final Color userAvatarFill;
  final Color userAvatarText;
  final Color cardFill;
  final Color cardBorder;
  final Color fieldFill;
  final Color micFill;
  final Color micIcon;
  final Color online;
  final Color link;

  /// The "+N" tile over the last gallery image.
  final Color overlay;

  /// Darkens the chat behind the attachment sheet.
  final Color sheetScrim;

  /// Author name above a row.
  final TextStyle name;

  ThreadFeedTokens._(
    super.base, {
    required this.divider,
    required this.agentAvatarFill,
    required this.agentAvatarText,
    required this.userAvatarFill,
    required this.userAvatarText,
    required this.cardFill,
    required this.cardBorder,
    required this.fieldFill,
    required this.micFill,
    required this.micIcon,
    required this.online,
    required this.link,
    required this.overlay,
    required this.sheetScrim,
    required this.name,
  }) : super.from();

  factory ThreadFeedTokens.from(ZukkoChatTheme theme) {
    const accentTone = (0xFF0F766E, 0xFF4FB7A9);
    final base = ChatBaseTokens.resolve(
      theme,
      family: 'Onest',
      scale: const ChatTypeScale(
        body: 15,
        bodyHeight: 1.5,
        strong: 14,
        caption: 12,
        status: 12.5,
      ),
      background: (0xFFFFFFFF, 0xFF111312),
      text: (0xFF1B1D1C, 0xFFE7E9E8),
      muted: (0xFF6A6F6C, 0xFF8E9591),
      accent: accentTone,
      onAccent: (0xFFFFFFFF, 0xFF0E1211),
      media: (0xFFDCE3DF, 0xFF232A27),
      mediaIcon: (0xFF6F7A74, 0xFF7D8781),
      icon: (0xFF4A4F4C, 0xFFB3BAB6),
      typingDot: (0xFF9AA19D, 0xFF5E6662),
      waveInactive: (0xFFBCC6C1, 0xFF3A423F),
      hint: (0xFF868B88, 0xFF7D8481),
    );
    final custom = theme.accentColor != null;
    return ThreadFeedTokens._(
      base,
      divider: theme.pick(0xFFECEDEC, 0xFF222624),
      agentAvatarFill: theme.accentOr((0xFF0F766E, 0xFF1E4A45)),
      agentAvatarText: theme.onAccentOr((0xFFFFFFFF, 0xFFA8E2D9)),
      userAvatarFill: theme.pick(0xFFE7EAE8, 0xFF2A2E2C),
      userAvatarText: theme.pick(0xFF3D433F, 0xFFC9CFCB),
      cardFill: theme.pick(0xFFFFFFFF, 0xFF161918),
      cardBorder: theme.pick(0xFFE4E6E5, 0xFF2A2F2D),
      fieldFill: theme.pick(0xFFF3F5F4, 0xFF1A1D1C),
      // The mic tile is a soft wash of the accent.
      micFill: custom
          ? ChatBaseTokens.tint(base.background, base.accent, 0.14)
          : theme.pick(0xFFE1EEEC, 0xFF1E3532),
      micIcon: theme.accentOr((0xFF0F766E, 0xFF6CC8BB)),
      online: theme.pick(0xFF2F9E6E, 0xFF4CC08A),
      link: theme.accentOr((0xFF0F766E, 0xFF6CC8BB)),
      overlay: const Color(0x73141816),
      sheetScrim: theme.pick(0x47111312, 0x99000000),
      name: theme.font(
        'Onest',
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: base.text,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
