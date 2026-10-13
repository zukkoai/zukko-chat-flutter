import 'package:flutter/material.dart';

import '../../core/chatwoot_callbacks.dart';
import '../l10n/chatwoot_l10n.dart';
import '../theme/chatwoot_chat_theme.dart';
import 'chatwoot_chat_controller.dart';
import 'chatwoot_chat_options.dart';
import 'chatwoot_chat_view.dart';

/// Chatwoot chat in a modal dialog with a title bar showing online/typing
/// status and a close button.
/// {@category FlutterClientSdk}
class ChatwootChatDialog extends StatelessWidget {
  /// Shows the dialog.
  static Future<void> show(
    BuildContext context, {
    required ChatwootChatOptions options,
    required String title,
    ChatwootCallbacks? callbacks,
    ChatwootChatInteractions interactions = const ChatwootChatInteractions(),
  }) => showDialog<void>(
    context: context,
    builder: (_) => ChatwootChatDialog(
      options: options,
      title: title,
      callbacks: callbacks,
      interactions: interactions,
    ),
  );

  final ChatwootChatOptions options;
  final String title;
  final ChatwootCallbacks? callbacks;

  /// UI events, see [ChatwootChatInteractions]
  final ChatwootChatInteractions interactions;

  /// Replaces `ChatwootClient.create` (tests).
  @visibleForTesting
  final ChatwootClientFactory? clientFactory;

  const ChatwootChatDialog({
    super.key,
    required this.options,
    required this.title,
    this.callbacks,
    this.interactions = const ChatwootChatInteractions(),
    this.clientFactory,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(8),
    clipBehavior: Clip.antiAlias,
    child: ChatwootChatView(
      options: options,
      callbacks: callbacks,
      interactions: interactions,
      compact: true,
      clientFactory: clientFactory,
      headerBuilder: (context, controller, theme) => _Header(
        title: title,
        controller: controller,
        l10n: options.l10n,
        theme: theme,
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  final String title;
  final ChatwootChatController controller;
  final ChatwootL10n l10n;
  final ChatwootChatTheme theme;

  const _Header({
    required this.title,
    required this.controller,
    required this.l10n,
    required this.theme,
  });

  String _statusText(ChatwootChatStatus s) => switch (s) {
    ChatwootChatStatus.offline => l10n.offlineText,
    ChatwootChatStatus.online => l10n.onlineText,
    ChatwootChatStatus.typing => l10n.typingText,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (controller.status != ChatwootChatStatus.offline)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsetsDirectional.only(start: 8),
                          decoration: BoxDecoration(
                            color: theme.onlineIndicatorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _statusText(controller.status),
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.closeLabel,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }
}
