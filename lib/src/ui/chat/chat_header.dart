import 'package:flutter/widgets.dart';

import '../l10n/zukko_chat_l10n.dart';
import 'zukko_chat_controller.dart';
import 'zukko_chat_style.dart';

/// Header the view draws itself (none when the host passes an app bar).
@immutable
class ChatViewHeader {
  /// Null falls back to [ZukkoChatL10n.headerTitle].
  final String? title;

  /// Show a back button that pops the route.
  final bool showBack;

  const ChatViewHeader({this.title, this.showBack = false});
}

/// The localised status line of the header.
extension ZukkoChatStatusText on ZukkoChatStatus {
  String label(ZukkoChatL10n l10n) => switch (this) {
    ZukkoChatStatus.offline => l10n.offlineText,
    ZukkoChatStatus.online => l10n.onlineText,
    ZukkoChatStatus.typing => l10n.typingText,
  };
}

/// The style's header, kept current with the chat status.
class ChatHeader extends StatelessWidget {
  final ZukkoChatController controller;
  final ChatStyle style;
  final ChatViewHeader header;
  final ZukkoChatL10n l10n;

  /// Menu button; hidden when null.
  final VoidCallback? onMore;

  const ChatHeader({
    super.key,
    required this.controller,
    required this.style,
    required this.header,
    required this.l10n,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.status;
        return style.buildHeader(
          context,
          ChatHeaderData(
            title: header.title ?? l10n.headerTitle,
            status: status.label(l10n),
            isOnline: status != ZukkoChatStatus.offline,
            onBack: header.showBack ? () => Navigator.maybePop(context) : null,
            onMore: onMore,
          ),
          l10n,
        );
      },
    ),
  );
}
