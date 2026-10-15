import 'package:flutter/widgets.dart';

import '../../../theme/chat_base_tokens.dart';
import '../../../theme/zukko_chat_theme.dart';

/// Smooth Silk: one cool pearl tone, bubbles a step lighter or darker than
/// the background, no borders or shadows, large even radii.
@immutable
class SmoothSilkTokens extends ChatBaseTokens {
  final Color incomingBubble;
  final Color outgoingBubble;
  final Color composerFill;
  final Color composerButtonFill;
  final Color waveActive;
  final Color playFill;
  final Color playIcon;
  final Color avatarFill;
  final Color avatarText;

  /// The "+N" tile over the last gallery image.
  final Color overlay;

  SmoothSilkTokens._(
    super.base, {
    required this.incomingBubble,
    required this.outgoingBubble,
    required this.composerFill,
    required this.composerButtonFill,
    required this.waveActive,
    required this.playFill,
    required this.playIcon,
    required this.avatarFill,
    required this.avatarText,
    required this.overlay,
  }) : super.from();

  factory SmoothSilkTokens.from(ZukkoChatTheme theme) {
    final base = ChatBaseTokens.resolve(
      theme,
      family: 'Manrope',
      scale: const ChatTypeScale(
        body: 15,
        bodyHeight: 1.45,
        caption: 11.5,
        status: 12.5,
      ),
      background: (0xFFEDF0F4, 0xFF15181D),
      text: (0xFF1F2733, 0xFFE6E9EE),
      muted: (0xFF66717F, 0xFF8E98A6),
      accent: (0xFF3A4A60, 0xFF9AADC6),
      onAccent: (0xFFF8FAFC, 0xFF15181D),
      media: (0xFFCBD3DE, 0xFF343C48),
      mediaIcon: (0xFF6A778A, 0xFF8794A6),
      icon: (0xFF4C5869, 0xFFA9B3C0),
      typingDot: (0xFFA6AFBB, 0xFF6E7887),
      waveInactive: (0xFFAEB8C6, 0xFF4A5463),
      captionColor: (0xFF7A8492, 0xFF7D8794),
      hint: (0xFF8A94A3, 0xFF7B8592),
    );
    return SmoothSilkTokens._(
      base,
      incomingBubble: theme.pick(0xFFF8FAFC, 0xFF1F242B),
      outgoingBubble: theme.pick(0xFFDCE2EA, 0xFF2A313B),
      composerFill: theme.pick(0xFFF8FAFC, 0xFF1F242B),
      // The attach disc is cut out of the composer in the background tone.
      composerButtonFill:
          theme.backgroundColor ?? theme.pick(0xFFEDF0F4, 0xFF2A313B),
      waveActive: theme.accentColor ?? theme.pick(0xFF3A4A60, 0xFFC9D2DE),
      playFill: theme.pick(0xFFF8FAFC, 0xFF3A4350),
      playIcon: theme.pick(0xFF2F3B4C, 0xFFE6E9EE),
      avatarFill: theme.pick(0xFFF8FAFC, 0xFF1F242B),
      avatarText: theme.pick(0xFF4A5A70, 0xFFB4C1D3),
      overlay: const Color(0x66000000),
    );
  }
}
