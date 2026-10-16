import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:intl/intl.dart';

import '../../core/zukko_chat_upload.dart';
import '../../data/models/zukko_chat_user.dart';
import '../l10n/zukko_chat_l10n.dart';
import '../theme/zukko_chat_theme.dart';
import 'zukko_chat_style.dart';

/// Everything needed to configure the native chat (`ZukkoChat`).
@immutable
class ZukkoChatOptions {
  /// Installation url for Zukko Chat
  final String baseUrl;

  /// Website token of the target web widget inbox.
  final String websiteToken;

  /// Persist the contact, conversation and messages to disk. When false
  /// everything is held in memory and dropped with the client.
  final bool enablePersistence;

  /// Custom user details to be attached to the Zukko Chat contact
  final ZukkoChatUser? user;

  /// Look of the chat, see [ZukkoChatStyle].
  final ZukkoChatStyle style;

  /// Base theme of the style (brightness, font, accent override); defaults
  /// to a `ZukkoChatTheme` in `ThemeData.extensions`, else one derived
  /// from the ambient theme.
  final ZukkoChatTheme? theme;

  /// Strings; null picks the built-in translation of the ambient locale
  /// ([ZukkoChatL10n.forLocale]).
  final ZukkoChatL10n? l10n;

  /// Message time format, defaults to `DateFormat.Hm()`
  final DateFormat? timeFormat;

  /// Attachment button: send photos and files (up to [ZukkoChatUpload.maxSizeMb] MB each).
  final bool enableAttachments;

  /// Hold-to-record microphone: send voice messages (up to 5 minutes, the server limit).
  /// The app needs the microphone permission entries (see README).
  final bool enableVoiceMessages;

  /// Fetch a preview card (title, description, image) for the first link of a
  /// message. Fetching contacts the linked site directly from the device, which
  /// reveals the device IP to it; turn off for privacy. Without it a link still
  /// shows its domain and address.
  final bool enableLinkPreviews;

  const ZukkoChatOptions({
    required this.baseUrl,
    required this.websiteToken,
    this.enablePersistence = true,
    this.user,
    this.style = ZukkoChatStyle.smoothSilk,
    this.theme,
    this.l10n,
    this.timeFormat,
    this.enableAttachments = true,
    this.enableVoiceMessages = true,
    this.enableLinkPreviews = true,
  });

  /// True when [other] talks to the same server, inbox and user, i.e. the
  /// client can be kept alive across a rebuild.
  bool sameConnection(ZukkoChatOptions other) =>
      baseUrl == other.baseUrl &&
      websiteToken == other.websiteToken &&
      enablePersistence == other.enablePersistence &&
      user == other.user;

  @override
  bool operator ==(Object other) =>
      other is ZukkoChatOptions &&
      sameConnection(other) &&
      style == other.style &&
      theme == other.theme &&
      l10n == other.l10n &&
      timeFormat == other.timeFormat &&
      enableAttachments == other.enableAttachments &&
      enableVoiceMessages == other.enableVoiceMessages &&
      enableLinkPreviews == other.enableLinkPreviews;

  @override
  int get hashCode => Object.hash(
    baseUrl,
    websiteToken,
    enablePersistence,
    user,
    style,
    theme,
    l10n,
    timeFormat,
    enableAttachments,
    enableVoiceMessages,
    enableLinkPreviews,
  );
}

/// What the host reacts to in the chat UI (`ZukkoChat`). Client events
/// are `ZukkoChatCallbacks`.
class ZukkoChatInteractions {
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

  const ZukkoChatInteractions({
    this.onEndReached,
    this.onEndReachedThreshold,
    this.onMessageLongPress,
    this.onMessageTap,
    this.onSendPressed,
    this.onMorePressed,
  });
}
