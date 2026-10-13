import 'package:flutter/material.dart';

import '../../core/chatwoot_callbacks.dart';
import 'chatwoot_chat_controller.dart';
import 'chatwoot_chat_options.dart';
import 'chatwoot_chat_view.dart';

/// Full-screen chatwoot chat.
/// {@category FlutterClientSdk}
class ChatwootChat extends StatelessWidget {
  final ChatwootChatOptions options;

  /// Specifies a custom app bar for the chat page
  final PreferredSizeWidget? appBar;

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
    this.callbacks,
    this.interactions = const ChatwootChatInteractions(),
    this.clientFactory,
  });

  // The view paints its own background over the whole body.
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: ChatwootChatView(
      options: options,
      callbacks: callbacks,
      interactions: interactions,
      clientFactory: clientFactory,
    ),
  );
}
