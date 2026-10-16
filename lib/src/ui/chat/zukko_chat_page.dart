import 'package:flutter/material.dart';

import '../../core/zukko_chat_callbacks.dart';
import 'zukko_chat_options.dart';
import 'zukko_chat_view.dart';

/// Full-screen Zukko Chat chat.
/// {@category FlutterClientSdk}
class ZukkoChat extends StatelessWidget {
  final ZukkoChatOptions options;

  /// Title of the style's header; defaults to `ZukkoChatL10n.headerTitle`.
  final String? title;

  /// Client events, see [ZukkoChatCallbacks]
  final ZukkoChatCallbacks? callbacks;

  /// UI events (scroll end, taps, send), see [ZukkoChatInteractions]
  final ZukkoChatInteractions interactions;

  const ZukkoChat({
    super.key,
    required this.options,
    this.title,
    this.callbacks,
    this.interactions = const ZukkoChatInteractions(),
  });

  // The view paints its own background and header over the whole body.
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ZukkoChatView(
      options: options,
      callbacks: callbacks,
      interactions: interactions,
      header: ChatViewHeader(title: title, showBack: Navigator.canPop(context)),
    ),
  );
}
