import 'package:flutter/material.dart';

import '../../core/chatwoot_callbacks.dart';
import 'chatwoot_chat_controller.dart';
import 'chatwoot_chat_options.dart';
import 'chatwoot_chat_view.dart';

/// Full-screen chatwoot chat.
/// {@category FlutterClientSdk}
class ChatwootChat extends StatelessWidget {
  final ChatwootChatOptions options;

  /// Replaces the style's own header with a custom app bar.
  final PreferredSizeWidget? appBar;

  /// Title of the style's header; defaults to `ChatwootL10n.headerTitle`.
  final String? title;

  /// Client events, see [ChatwootCallbacks]
  final ChatwootCallbacks? callbacks;

  /// UI events (scroll end, taps, send), see [ChatwootChatInteractions]
  final ChatwootChatInteractions interactions;

  /// Replaces `ChatwootClient.create` (tests).
  @visibleForTesting
  final ChatwootClientFactory? clientFactory;

  const ChatwootChat({
    super.key,
    required this.options,
    this.appBar,
    this.title,
    this.callbacks,
    this.interactions = const ChatwootChatInteractions(),
    this.clientFactory,
  });

  // The view paints its own background and header over the whole body.
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: ChatwootChatView(
      options: options,
      callbacks: callbacks,
      interactions: interactions,
      clientFactory: clientFactory,
      header: appBar != null
          ? null
          : ChatViewHeader(title: title, showBack: Navigator.canPop(context)),
    ),
  );
}
