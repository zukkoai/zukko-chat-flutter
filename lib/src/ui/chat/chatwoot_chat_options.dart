import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:intl/intl.dart';

import '../../data/models/chatwoot_user.dart';
import '../l10n/chatwoot_l10n.dart';
import '../theme/chatwoot_chat_theme.dart';
import 'chatwoot_chat_style.dart';

/// Everything needed to configure the native chat (`ChatwootChat`).
@immutable
class ChatwootChatOptions {
  /// Installation url for chatwoot
  final String baseUrl;

  /// Website token of the target web widget inbox.
  final String websiteToken;

  /// Persist the contact, conversation and messages to disk. When false
  /// everything is held in memory and dropped with the client.
  final bool enablePersistence;

  /// Allow a plain `http://` [baseUrl] that is not loopback. Development only.
  final bool allowInsecure;

  /// Custom user details to be attached to the chatwoot contact
  final ChatwootUser? user;

  /// Look of the chat, see [ChatwootChatStyle].
  final ChatwootChatStyle style;

  /// Base theme of the style (brightness, font, accent override); defaults
  /// to a `ChatwootChatTheme` in `ThemeData.extensions`, else one derived
  /// from the ambient theme.
  final ChatwootChatTheme? theme;

  /// Strings; null picks the built-in translation of the ambient locale
  /// ([ChatwootL10n.forLocale]).
  final ChatwootL10n? l10n;

  /// Message time format, defaults to `DateFormat.Hm()`
  final DateFormat? timeFormat;

  /// Show the "Powered by zukko.ai" footer.
  final bool showBranding;

  /// Attachment button: send photos and files (up to 40 MB each).
  final bool enableAttachments;

  /// Hold-to-record microphone: send voice messages (up to 5 minutes).
  /// The app needs the microphone permission entries (see README).
  final bool enableVoiceMessages;

  const ChatwootChatOptions({
    required this.baseUrl,
    required this.websiteToken,
    this.enablePersistence = true,
    this.allowInsecure = false,
    this.user,
    this.style = ChatwootChatStyle.smoothSilk,
    this.theme,
    this.l10n,
    this.timeFormat,
    this.showBranding = true,
    this.enableAttachments = true,
    this.enableVoiceMessages = true,
  });

  /// True when [other] talks to the same server, inbox and user, i.e. the
  /// client can be kept alive across a rebuild.
  bool sameConnection(ChatwootChatOptions other) =>
      baseUrl == other.baseUrl &&
      websiteToken == other.websiteToken &&
      enablePersistence == other.enablePersistence &&
      allowInsecure == other.allowInsecure &&
      user == other.user;

  @override
  bool operator ==(Object other) =>
      other is ChatwootChatOptions &&
      sameConnection(other) &&
      style == other.style &&
      theme == other.theme &&
      l10n == other.l10n &&
      timeFormat == other.timeFormat &&
      showBranding == other.showBranding &&
      enableAttachments == other.enableAttachments &&
      enableVoiceMessages == other.enableVoiceMessages;

  @override
  int get hashCode => Object.hash(
    baseUrl,
    websiteToken,
    enablePersistence,
    allowInsecure,
    user,
    style,
    theme,
    l10n,
    timeFormat,
    showBranding,
    enableAttachments,
    enableVoiceMessages,
  );
}

/// What the host reacts to in the chat UI (`ChatwootChat`). Client events
/// are `ChatwootCallbacks`.
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

  /// Menu button of the chat header; hidden when null.
  final VoidCallback? onMorePressed;

  const ChatwootChatInteractions({
    this.onEndReached,
    this.onEndReachedThreshold,
    this.onMessageLongPress,
    this.onMessageTap,
    this.onSendPressed,
    this.onMorePressed,
  });
}
