import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../l10n/chatwoot_l10n.dart';
import '../theme/chatwoot_chat_theme.dart';
import 'styles/classic_style.dart';

/// Inputs every style gets to build its message list and composer.
class ChatwootStyleArgs {
  final ChatwootChatTheme theme;
  final ChatwootL10n l10n;
  final bool showUserAvatars;
  final bool showUserNames;
  final Future<void> Function()? onEndReached;
  final double? paginationThreshold;

  const ChatwootStyleArgs({
    required this.theme,
    required this.l10n,
    required this.showUserAvatars,
    required this.showUserNames,
    this.onEndReached,
    this.paginationThreshold,
  });
}

/// Selectable looks of the native chat. A new style is one file in `styles/`
/// returning [Builders], plus one entry here.
enum ChatwootChatStyle {
  classic;

  Builders builders(ChatwootStyleArgs args) => switch (this) {
    ChatwootChatStyle.classic => classicBuilders(args),
  };
}
