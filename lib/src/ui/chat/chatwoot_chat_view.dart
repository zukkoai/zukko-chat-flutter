import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:material_ui/material_ui.dart' as mui;

import '../../core/chatwoot_callbacks.dart';
import '../../core/chatwoot_client.dart';
import '../l10n/chatwoot_l10n.dart';
import '../theme/chatwoot_chat_theme.dart';
import 'chatwoot_chat_controller.dart';
import 'chatwoot_chat_options.dart';
import 'chatwoot_chat_style.dart';

/// Message list + composer + footer. `ChatwootChat` and `ChatwootChatDialog`
/// are thin wrappers around this (internal, not exported).
class ChatwootChatView extends StatefulWidget {
  final ChatwootChatOptions options;

  /// Consumer callbacks, called after the view has handled the event.
  final ChatwootCallbacks? callbacks;

  /// Optional widget above the message list, e.g. the dialog title bar.
  /// Gets the theme the view resolved, so it is resolved once.
  final Widget Function(
    BuildContext context,
    ChatwootChatController controller,
    ChatwootChatTheme theme,
  )?
  headerBuilder;

  /// Reduced horizontal padding (used in dialogs).
  final bool compact;

  final ChatwootChatInteractions interactions;

  @visibleForTesting
  final ChatwootClientFactory? clientFactory;

  const ChatwootChatView({
    super.key,
    required this.options,
    this.callbacks,
    this.headerBuilder,
    this.compact = false,
    this.interactions = const ChatwootChatInteractions(),
    this.clientFactory,
  });

  @override
  State<ChatwootChatView> createState() => _ChatwootChatViewState();
}

class _ChatwootChatViewState extends State<ChatwootChatView> {
  late ChatwootChatController _controller = _createController();

  ChatwootChatController _createController() => ChatwootChatController(
    widget.options,
    callbacks: widget.callbacks,
    clientFactory: widget.clientFactory ?? ChatwootClient.create,
  );

  @override
  void didUpdateWidget(ChatwootChatView old) {
    super.didUpdateWidget(old);
    if (!widget.options.sameConnection(old.options)) {
      _controller.dispose();
      _controller = _createController();
    } else {
      _controller.l10n = widget.options.l10n;
      _controller.callbacks = widget.callbacks;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(
    BuildContext context,
    Message message, {
    required int index,
    required TapUpDetails details,
  }) {
    if (message.status == MessageStatus.error &&
        message.authorId == _controller.currentUserId) {
      _controller.resend(message.id);
    }
    widget.interactions.onMessageTap?.call(message);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    final i = widget.interactions;
    var theme = ChatwootChatTheme.resolve(context, o.theme);
    if (widget.compact) theme = theme.copyWith(horizontalPadding: 8);
    final builders = o.style.builders(
      ChatwootStyleArgs(
        theme: theme,
        l10n: o.l10n,
        showUserAvatars: o.showUserAvatars,
        showUserNames: o.showUserNames,
        onEndReached: i.onEndReached,
        paginationThreshold: i.onEndReachedThreshold,
      ),
    );
    return ColoredBox(
      color: theme.backgroundColor,
      child: Column(
        children: [
          if (widget.headerBuilder != null)
            widget.headerBuilder!(context, _controller, theme),
          _ErrorBanner(controller: _controller, l10n: o.l10n, theme: theme),
          Flexible(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.horizontalPadding,
              ),
              // flutter_chat_ui draws with material_ui, a separate widget
              // set from flutter/material: it needs its own Material and
              // Theme ancestors even inside a flutter MaterialApp.
              child: mui.Theme(
                data: mui.ThemeData(
                  colorScheme: mui.ColorScheme.fromSeed(
                    seedColor: theme.primaryColor,
                    brightness: ThemeData.estimateBrightnessForColor(
                      theme.backgroundColor,
                    ),
                  ),
                ),
                // Fall back to the English strings of material_ui when the
                // app only provides flutter/material localizations.
                child: Localizations.override(
                  context: context,
                  delegates: [mui.DefaultMaterialLocalizations.delegate],
                  child: mui.Material(
                    type: mui.MaterialType.transparency,
                    child: Chat(
                      currentUserId: _controller.currentUserId,
                      resolveUser: _controller.resolveUser,
                      chatController: _controller.chat,
                      onMessageSend: (text) {
                        _controller.send(text);
                        i.onSendPressed?.call(text);
                      },
                      onMessageTap: _onTap,
                      onMessageLongPress: i.onMessageLongPress == null
                          ? null
                          : (
                              context,
                              message, {
                              required index,
                              required details,
                            }) => i.onMessageLongPress!(context, message),
                      timeFormat: o.timeFormat ?? DateFormat.Hm(),
                      theme: theme.toChatTheme(),
                      backgroundColor: theme.backgroundColor,
                      builders: builders,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (o.showBranding)
            _Branding(text: o.l10n.poweredByText, theme: theme),
        ],
      ),
    );
  }
}

/// Shown while the chat could not be started, with a retry button.
class _ErrorBanner extends StatelessWidget {
  final ChatwootChatController controller;
  final ChatwootL10n l10n;
  final ChatwootChatTheme theme;

  const _ErrorBanner({
    required this.controller,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.error == null) return const SizedBox.shrink();
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.horizontalPadding,
            vertical: 4,
          ),
          child: Row(
            children: [
              Expanded(child: Text(l10n.connectionErrorText)),
              TextButton(
                onPressed: controller.retry,
                child: Text(l10n.retryLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Branding extends StatelessWidget {
  final String text;
  final ChatwootChatTheme theme;

  const _Branding({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/logo_grey.png',
          package: 'chatwoot_sdk',
          width: 15,
          height: 15,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const SizedBox(width: 15),
        ),
        const SizedBox(width: 8),
        Text(text, style: theme.brandingTextStyle),
      ],
    ),
  );
}
