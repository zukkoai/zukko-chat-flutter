import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../../../l10n/zukko_chat_l10n.dart';
import '../../../theme/chat_base_tokens.dart';
import '../../../theme/zukko_chat_theme.dart';
import '../../components/components.dart';
import '../../zukko_chat_style.dart';
import 'message_builders.dart';

/// The three surface shades and the corner radius flutter_chat_ui's own
/// widgets (scroll-to-bottom, load more) take from the style.
@immutable
class ChatSurfaces {
  final Color container;
  final Color containerLow;
  final Color containerHigh;
  final double radius;

  const ChatSurfaces({
    required this.container,
    required this.containerLow,
    required this.containerHigh,
    required this.radius,
  });
}

/// What the three styles share of [ChatStyle]: the getters, the cached
/// flutter_chat_ui theme, the footer and the message builders. A style adds
/// its header, composer, typing row and [messageSpec].
abstract class BaseChatStyle extends ChatStyle {
  final ZukkoChatTheme theme;
  final ChatBaseTokens base;
  final ChatSurfaces surfaces;

  /// Font size of the "Powered by" line (the caption's when null).
  final double? footerFontSize;

  /// Color of its link.
  final Color footerLinkColor;

  BaseChatStyle({
    required this.theme,
    required this.base,
    required this.surfaces,
    required this.footerLinkColor,
    this.footerFontSize,
  });

  /// The chat's horizontal gap (from the theme).
  double get horizontalPadding => theme.horizontalPadding;

  /// Values for the shared message builders.
  MessageStyleSpec get messageSpec;

  @override
  Brightness get brightness => base.brightness;

  @override
  Color get backgroundColor => base.background;

  @override
  Color get foregroundColor => base.text;

  @override
  Color get accentColor => base.accent;

  @override
  late final ChatTheme chatTheme = ChatTheme(
    colors: ChatColors(
      primary: base.accent,
      onPrimary: base.onAccent,
      surface: base.background,
      onSurface: base.text,
      surfaceContainer: surfaces.container,
      surfaceContainerLow: surfaces.containerLow,
      surfaceContainerHigh: surfaces.containerHigh,
    ),
    typography: ChatTypography.standard().copyWith(
      bodyMedium: base.body,
      labelSmall: base.caption,
    ),
    shape: BorderRadius.circular(surfaces.radius),
  );

  @override
  Widget buildFooter(BuildContext context, ZukkoChatL10n l10n) {
    final size = footerFontSize;
    return PoweredBy(
      prefix: l10n.poweredByText,
      style: size == null
          ? base.caption
          : base.caption.copyWith(fontSize: size),
      linkColor: footerLinkColor,
    );
  }

  @override
  Builders messageBuilders(ChatMessageEnv env) =>
      buildMessageBuilders(env, messageSpec);
}
