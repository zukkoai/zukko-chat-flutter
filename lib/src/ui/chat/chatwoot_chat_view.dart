import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:material_ui/material_ui.dart' as mui;

import '../../core/chatwoot_callbacks.dart';
import '../../core/chatwoot_client.dart';
import '../../core/chatwoot_client_exception.dart';
import '../l10n/chatwoot_l10n.dart';
import '../theme/chatwoot_chat_theme.dart';
import 'chatwoot_chat_controller.dart';
import 'chatwoot_chat_options.dart';
import 'chatwoot_chat_style.dart';
import 'components/attachment_picker.dart';
import 'components/audio_playback.dart';
import 'components/voice_recorder.dart';

/// Header the view draws itself (none when the host passes an app bar).
@immutable
class ChatViewHeader {
  /// Null falls back to [ZukkoChatL10n.headerTitle].
  final String? title;

  /// Show a back button that pops the route.
  final bool showBack;

  const ChatViewHeader({this.title, this.showBack = false});
}

/// Header + message list + composer + footer, drawn by the selected
/// [ZukkoChatStyle]. `ZukkoChat` is a thin wrapper around this
/// (internal, not exported).
///
/// The theme is resolved once here (app theme -> [ZukkoChatTheme] ->
/// style tokens) and passed down.
class ZukkoChatView extends StatefulWidget {
  final ZukkoChatOptions options;

  /// Consumer callbacks, called after the view has handled the event.
  final ZukkoChatCallbacks? callbacks;

  final ChatViewHeader? header;

  final ZukkoChatInteractions interactions;

  @visibleForTesting
  final ZukkoChatClientFactory? clientFactory;

  const ZukkoChatView({
    super.key,
    required this.options,
    this.callbacks,
    this.header,
    this.interactions = const ZukkoChatInteractions(),
    this.clientFactory,
  });

  @override
  State<ZukkoChatView> createState() => _ZukkoChatViewState();
}

class _ZukkoChatViewState extends State<ZukkoChatView>
    with WidgetsBindingObserver {
  late ZukkoChatController _controller = _createController();
  final _audio = AudioPlaybackController();
  ZukkoChatL10n _l10n = const ZukkoChatL10n();

  ZukkoChatController _createController() => ZukkoChatController(
    widget.options,
    callbacks: widget.callbacks,
    clientFactory: widget.clientFactory ?? ZukkoChatClient.create,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Only a resumed app shows the chat to the user.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _controller.visible = state == AppLifecycleState.resumed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncL10n();
  }

  @override
  void didUpdateWidget(ZukkoChatView old) {
    super.didUpdateWidget(old);
    if (!widget.options.sameConnection(old.options)) {
      _controller.dispose();
      _controller = _createController();
    } else {
      _controller.callbacks = widget.callbacks;
    }
    _syncL10n();
  }

  /// Explicit strings, else the translation of the ambient locale.
  void _syncL10n() {
    _l10n =
        widget.options.l10n ??
        ZukkoChatL10n.forLocale(Localizations.maybeLocaleOf(context));
    _controller.l10n = _l10n;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _audio.dispose();
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

  void _send(String text) {
    _controller.send(text);
    widget.interactions.onSendPressed?.call(text);
  }

  /// Photo or file sheet, system picker, size check, send.
  Future<void> _attach(ChatStyle style) async {
    final source = await showAttachmentSourceSheet(
      context,
      l10n: _l10n,
      background: style.backgroundColor,
      foreground: style.foregroundColor,
    );
    if (source == null || !mounted) return;
    final files = await pickAttachments(source);
    if (files.isEmpty || !mounted) return;
    final fitting = [
      for (final f in files)
        if (!f.isTooLarge) f,
    ];
    if (fitting.length < files.length) _notify(_l10n.fileTooLargeText);
    _controller.sendAttachments(fitting);
  }

  void _sendVoice(VoiceRecording recording) => _controller.sendAttachments([
    recording.file,
  ], audioDuration: recording.duration);

  void _onVoiceIssue(VoiceRecorderIssue issue) => _notify(switch (issue) {
    VoiceRecorderIssue.permissionDenied => _l10n.microphoneDeniedText,
    VoiceRecorderIssue.failed => _l10n.voiceRecordFailedText,
  });

  void _notify(String text) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  ChatHeaderData _headerData(ChatViewHeader header) {
    final status = _controller.status;
    return ChatHeaderData(
      title: header.title ?? _l10n.headerTitle,
      status: switch (status) {
        ZukkoChatStatus.offline => _l10n.offlineText,
        ZukkoChatStatus.online => _l10n.onlineText,
        ZukkoChatStatus.typing => _l10n.typingText,
      },
      isOnline: status != ZukkoChatStatus.offline,
      onBack: header.showBack ? () => Navigator.maybePop(context) : null,
      onMore: widget.interactions.onMorePressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    final i = widget.interactions;
    final l10n = _l10n;
    final theme = ZukkoChatTheme.resolve(context, o.theme);
    final style = o.style.resolve(theme);
    final header = widget.header;

    return ColoredBox(
      color: style.backgroundColor,
      child: Column(
        children: [
          if (header != null)
            SafeArea(
              bottom: false,
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) =>
                    style.buildHeader(context, _headerData(header), l10n),
              ),
            ),
          _ErrorBanner(
            controller: _controller,
            l10n: l10n,
            color: style.foregroundColor,
            horizontalPadding: theme.horizontalPadding,
          ),
          Expanded(
            child: _MessageList(
              controller: _controller,
              style: style,
              interactions: i,
              onTap: _onTap,
              env: ChatMessageEnv(
                l10n: l10n,
                timeFormat: o.timeFormat ?? DateFormat.Hm(),
                userById: _controller.userById,
                horizontalPadding: theme.horizontalPadding,
                audio: _audio,
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                style.buildComposer(
                  context,
                  ChatComposerData(
                    onSend: _send,
                    onTyping: _controller.typing,
                    onAttach: o.enableAttachments
                        ? () => unawaited(_attach(style))
                        : null,
                    onVoiceRecorded: o.enableVoiceMessages ? _sendVoice : null,
                    onVoiceIssue: _onVoiceIssue,
                  ),
                  l10n,
                ),
                if (o.showBranding) style.buildFooter(context, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// flutter_chat_ui list with the style's message builders. The composer is
/// drawn by the view below the list, so the list's own one is empty.
class _MessageList extends StatelessWidget {
  final ZukkoChatController controller;
  final ChatStyle style;
  final ZukkoChatInteractions interactions;
  final ChatMessageEnv env;
  final OnMessageTapCallback onTap;

  const _MessageList({
    required this.controller,
    required this.style,
    required this.interactions,
    required this.env,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final i = interactions;
    final onLongPress = i.onMessageLongPress;
    final builders = style
        .messageBuilders(env)
        .copyWith(
          chatAnimatedListBuilder: (context, itemBuilder) => ChatAnimatedList(
            itemBuilder: itemBuilder,
            onEndReached: i.onEndReached,
            paginationThreshold: i.onEndReachedThreshold ?? 0.01,
            handleSafeArea: false,
            bottomPadding: 12,
            bottomSliver: SliverToBoxAdapter(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) =>
                    controller.status == ZukkoChatStatus.typing
                    ? style.buildTypingIndicator(context, env.l10n)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          composerBuilder: (context) => const SizedBox.shrink(),
        );
    // flutter_chat_ui draws with material_ui, a separate widget set from
    // flutter/material: it needs its own Material and Theme ancestors even
    // inside a flutter MaterialApp.
    return mui.Theme(
      data: mui.ThemeData(
        colorScheme: mui.ColorScheme.fromSeed(
          seedColor: style.accentColor,
          brightness: style.brightness,
        ),
      ),
      // Fall back to the English strings of material_ui when the app only
      // provides flutter/material localizations.
      child: Localizations.override(
        context: context,
        delegates: [mui.DefaultMaterialLocalizations.delegate],
        child: mui.Material(
          type: mui.MaterialType.transparency,
          child: Chat(
            currentUserId: controller.currentUserId,
            resolveUser: controller.resolveUser,
            chatController: controller.chat,
            onMessageTap: onTap,
            onMessageLongPress: onLongPress == null
                ? null
                : (context, message, {required index, required details}) =>
                      onLongPress(context, message),
            timeFormat: env.timeFormat,
            theme: style.chatTheme,
            backgroundColor: style.backgroundColor,
            builders: builders,
          ),
        ),
      ),
    );
  }
}

/// Shown while the chat could not be started, with a retry button.
class _ErrorBanner extends StatelessWidget {
  final ZukkoChatController controller;
  final ZukkoChatL10n l10n;
  final Color color;
  final double horizontalPadding;

  const _ErrorBanner({
    required this.controller,
    required this.l10n,
    required this.color,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final error = controller.error;
      if (error == null) return const SizedBox.shrink();
      final rejected =
          error.type == ZukkoChatExceptionType.INVALID_IDENTIFIER_HASH;
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(switch (error.type) {
                  ZukkoChatExceptionType.INVALID_IDENTIFIER_HASH =>
                    l10n.identityRejectedText,
                  ZukkoChatExceptionType.SESSION_EXPIRED =>
                    l10n.sessionExpiredText,
                  _ => l10n.connectionErrorText,
                }, style: TextStyle(color: color)),
              ),
              // the same identity would be rejected again
              if (!rejected)
                TextButton(
                  onPressed: controller.retry,
                  style: TextButton.styleFrom(foregroundColor: color),
                  child: Text(l10n.retryLabel),
                ),
            ],
          ),
        ),
      );
    },
  );
}
