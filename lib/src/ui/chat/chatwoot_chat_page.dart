import 'package:flutter/material.dart';

import '../../core/chatwoot_callbacks.dart';
import 'chatwoot_chat_controller.dart';
import 'chatwoot_chat_options.dart';
import 'chatwoot_chat_view.dart';

/// Full-screen Zukko Chat chat.
/// {@category FlutterClientSdk}
class ZukkoChat extends StatelessWidget {
  final ZukkoChatOptions options;

  /// Replaces the style's own header with a custom app bar.
  final PreferredSizeWidget? appBar;

  /// Title of the style's header; defaults to `ZukkoChatL10n.headerTitle`.
  final String? title;

  /// Client events, see [ZukkoChatCallbacks]
  final ZukkoChatCallbacks? callbacks;

  /// UI events (scroll end, taps, send), see [ZukkoChatInteractions]
  final ZukkoChatInteractions interactions;

  /// Replaces `ZukkoChatClient.create` (tests).
  @visibleForTesting
  final ZukkoChatClientFactory? clientFactory;

  const ZukkoChat({
    super.key,
    required this.options,
    this.appBar,
    this.title,
    this.callbacks,
    this.interactions = const ZukkoChatInteractions(),
    this.clientFactory,
  });

  // The view paints its own background and header over the whole body.
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: ZukkoChatView(
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
