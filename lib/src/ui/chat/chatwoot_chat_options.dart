import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:intl/intl.dart';

import '../../data/models/chatwoot_user.dart';
import '../l10n/chatwoot_l10n.dart';
import '../theme/chatwoot_chat_theme.dart';
import 'chatwoot_chat_style.dart';

/// Everything needed to configure a native chat, shared by `ChatwootChat` and
/// `ChatwootChatDialog`.
@immutable
class ChatwootChatOptions {
  /// Installation url for chatwoot
  final String baseUrl;

  /// Identifier for target chatwoot inbox.
  ///
  /// For more details see https://www.chatwoot.com/docs/product/channels/api/client-apis
  final String inboxIdentifier;

  /// Persist the contact, conversation and messages to disk. When false
  /// everything is held in memory and dropped with the client.
  final bool enablePersistence;

  /// Allow a plain `http://` [baseUrl] that is not loopback. Development only.
  final bool allowInsecure;

  /// Custom user details to be attached to the chatwoot contact
  final ChatwootUser? user;

  /// Theme; defaults to one derived from the ambient `ColorScheme`
  /// (or a `ChatwootChatTheme` registered in `ThemeData.extensions`).
  final ChatwootChatTheme? theme;

  /// See [ChatwootL10n]
  final ChatwootL10n l10n;

  /// Message time format, defaults to `DateFormat.Hm()`
  final DateFormat? timeFormat;

  /// Show avatars for received messages.
  final bool showUserAvatars;

  /// Show user names for received messages.
  final bool showUserNames;

  /// Show the "Powered by Chatwoot" footer.
  final bool showBranding;

  /// Visual style of the message list and composer.
  final ChatwootChatStyle style;

  const ChatwootChatOptions({
    required this.baseUrl,
    required this.inboxIdentifier,
    this.enablePersistence = true,
    this.allowInsecure = false,
    this.user,
    this.theme,
    this.l10n = const ChatwootL10n(),
    this.timeFormat,
    this.showUserAvatars = true,
    this.showUserNames = true,
    this.showBranding = true,
    this.style = ChatwootChatStyle.classic,
  });

  /// True when [other] talks to the same server, inbox and user, i.e. the
  /// client can be kept alive across a rebuild.
  bool sameConnection(ChatwootChatOptions other) =>
      baseUrl == other.baseUrl &&
      inboxIdentifier == other.inboxIdentifier &&
      enablePersistence == other.enablePersistence &&
      allowInsecure == other.allowInsecure &&
      user == other.user;

  @override
  bool operator ==(Object other) =>
      other is ChatwootChatOptions &&
      sameConnection(other) &&
      theme == other.theme &&
      l10n == other.l10n &&
      timeFormat == other.timeFormat &&
      showUserAvatars == other.showUserAvatars &&
      showUserNames == other.showUserNames &&
      showBranding == other.showBranding &&
      style == other.style;

  @override
  int get hashCode => Object.hash(
    baseUrl,
    inboxIdentifier,
    enablePersistence,
    allowInsecure,
    user,
    theme,
    l10n,
    timeFormat,
    showUserAvatars,
    showUserNames,
    showBranding,
    style,
  );
}

/// What the host reacts to in the chat UI; shared by `ChatwootChat` and
/// `ChatwootChatDialog`. (Client events are `ChatwootCallbacks`.)
class ChatwootChatInteractions {
  /// Called when the top of the list (oldest message) is reached.
  final Future<void> Function()? onEndReached;

  /// Fraction (0..1) of the list at which [onEndReached] triggers.
  final double? onEndReachedThreshold;

  final void Function(BuildContext context, Message message)?
  onMessageLongPress;
  final void Function(Message message)? onMessageTap;

  /// Called with the text the user sent.
  final void Function(String text)? onSendPressed;

  const ChatwootChatInteractions({
    this.onEndReached,
    this.onEndReachedThreshold,
    this.onMessageLongPress,
    this.onMessageTap,
    this.onSendPressed,
  });
}
