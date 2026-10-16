import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../l10n/zukko_chat_l10n.dart';
import '../theme/zukko_chat_theme.dart';
import 'components/components.dart';
import 'styles/minimal_clean/minimal_clean_style.dart';
import 'styles/smooth_silk/smooth_silk_style.dart';
import 'styles/thread_feed/thread_feed_style.dart';

/// Selectable looks of the native chat. Each has a light and a dark variant,
/// picked by `ZukkoChatTheme.brightness`.
enum ZukkoChatStyle {
  /// Tonal bubbles that blend into the background, floating composer.
  smoothSilk,

  /// Agent replies as plain text, only the user's messages in bubbles.
  minimalClean,

  /// Full-width rows with avatar and name, no bubbles.
  threadFeed;

  /// The style resolved against [theme]; the view does this once per build.
  ChatStyle resolve(ZukkoChatTheme theme) => switch (this) {
    ZukkoChatStyle.smoothSilk => SmoothSilkStyle(theme),
    ZukkoChatStyle.minimalClean => MinimalCleanStyle(theme),
    ZukkoChatStyle.threadFeed => ThreadFeedStyle(theme),
  };
}

/// What every style provides. Implementations live in `styles/<name>/` and
/// only depend on this file, `components/` and the theme.
abstract class ChatStyle {
  const ChatStyle();

  Brightness get brightness;

  /// Paints behind header, messages and composer.
  Color get backgroundColor;

  /// Default text color on [backgroundColor] (error banner, empty states).
  Color get foregroundColor;

  /// Seed of the flutter_chat_ui internals (scroll-to-bottom, load more).
  Color get accentColor;

  /// Theme of the flutter_chat_ui internals.
  ChatTheme get chatTheme;

  Widget buildHeader(
    BuildContext context,
    ChatHeaderData data,
    ZukkoChatL10n l10n,
  );

  Widget buildComposer(
    BuildContext context,
    ChatComposerData data,
    ZukkoChatL10n l10n,
  );

  /// Shown below the last message while the agent is typing.
  Widget buildTypingIndicator(BuildContext context, ZukkoChatL10n l10n);

  /// "Powered by zukko.ai" under the composer.
  Widget buildFooter(BuildContext context, ZukkoChatL10n l10n);

  /// Message builders (text, image, gallery, file, audio) and the row wrapper.
  Builders messageBuilders(ChatMessageEnv env);
}

/// Input of [ChatStyle.buildHeader]; rebuilt when the chat status changes.
@immutable
class ChatHeaderData {
  final String title;

  /// Localised online / offline / typing text.
  final String status;
  final bool isOnline;

  /// Back button; null hides it.
  final VoidCallback? onBack;

  /// Null hides the menu button.
  final VoidCallback? onMore;

  const ChatHeaderData({
    required this.title,
    required this.status,
    required this.isOnline,
    this.onBack,
    this.onMore,
  });
}

/// Input of [ChatStyle.buildComposer].
@immutable
class ChatComposerData {
  /// Called with the trimmed, non-empty text.
  final ValueChanged<String> onSend;

  /// Null hides the attachment button.
  final VoidCallback? onAttach;

  /// A finished voice message to send; null hides the microphone button.
  final ValueChanged<VoiceRecording>? onVoiceRecorded;

  /// The microphone was refused or failed.
  final ValueChanged<VoiceRecorderIssue>? onVoiceIssue;

  /// The text changed (the user is typing).
  final VoidCallback? onTyping;

  /// The text went over the server limit (sending is off until shortened).
  final VoidCallback? onTooLong;

  const ChatComposerData({
    required this.onSend,
    this.onTyping,
    this.onAttach,
    this.onVoiceRecorded,
    this.onVoiceIssue,
    this.onTooLong,
  });
}

/// Read-only context of the message builders.
@immutable
class ChatMessageEnv {
  final ZukkoChatL10n l10n;
  final DateFormat timeFormat;

  /// Name / avatar of an author, synchronously (null when unknown).
  final User? Function(String userId) userById;

  /// Display name of an author ("You" for the visitor, a fallback title when unnamed).
  final String Function(String userId, bool isSentByMe) authorName;

  /// Horizontal gap between the screen edge and a message.
  final double horizontalPadding;

  /// Plays voice messages (one at a time).
  final AudioPlaybackController audio;

  const ChatMessageEnv({
    required this.l10n,
    required this.timeFormat,
    required this.userById,
    required this.authorName,
    required this.horizontalPadding,
    required this.audio,
  });
}
