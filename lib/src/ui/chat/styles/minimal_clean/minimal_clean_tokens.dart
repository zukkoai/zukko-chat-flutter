import 'package:flutter/widgets.dart';

import '../../../theme/chat_base_tokens.dart';
import '../../../theme/zukko_chat_theme.dart';

/// Minimal Clean: neutral white / near-black, agent text without bubbles,
/// a single ink accent.
@immutable
class MinimalCleanTokens extends ChatBaseTokens {
  final Color divider;
  final Color outgoingBubble;
  final Color composerFill;
  final Color composerBorder;

  /// The "+N" tile over the last gallery image.
  final Color overlay;

  /// Darkens the chat behind the attachment sheet.
  final Color sheetScrim;

  MinimalCleanTokens._(
    super.base, {
    required this.divider,
    required this.outgoingBubble,
    required this.composerFill,
    required this.composerBorder,
    required this.overlay,
    required this.sheetScrim,
  }) : super.from();

  factory MinimalCleanTokens.from(ZukkoChatTheme theme) {
    final base = ChatBaseTokens.resolve(
      theme,
      family: 'Geist',
      scale: const ChatTypeScale(
        body: 15.5,
        bodyHeight: 1.55,
        caption: 12,
        status: 12,
      ),
      background: (0xFFFCFCFB, 0xFF121212),
      text: (0xFF1A1A19, 0xFFECECEA),
      muted: (0xFF6B6B67, 0xFF9A9A95),
      accent: (0xFF1A1A19, 0xFFECECEA),
      onAccent: (0xFFFFFFFF, 0xFF121212),
      media: (0xFFECECE9, 0xFF262625),
      mediaIcon: (0xFF7A7A75, 0xFF8F8F8A),
      icon: (0xFF4A4A47, 0xFFBDBDB8),
      typingDot: (0xFF9A9A95, 0xFF8A8A85),
      waveInactive: (0xFFC4C4BF, 0xFF4A4A48),
      hint: (0xFF8E8E89, 0xFF7C7C78),
    );
    // With the app's own background the surfaces are derived from it, so
    // the composer and the bubbles never melt into it.
    final custom = theme.backgroundColor != null;
    Color surface(Tone t, double alpha) => custom
        ? ChatBaseTokens.tint(base.background, base.text, alpha)
        : theme.tone(t);
    return MinimalCleanTokens._(
      base,
      divider: surface((0xFFEFEFEC, 0xFF222221), 0.08),
      outgoingBubble: surface((0xFFF0F0EE, 0xFF232322), 0.07),
      composerFill: custom
          ? base.background
          : theme.pick(0xFFFFFFFF, 0xFF1B1B1A),
      composerBorder: surface((0xFFE4E4E1, 0xFF2C2C2A), 0.14),
      overlay: const Color(0x73000000),
      sheetScrim: theme.pick(0x38000000, 0x8C000000),
    );
  }
}
