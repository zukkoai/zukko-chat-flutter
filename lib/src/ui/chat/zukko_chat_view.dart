import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:material_ui/material_ui.dart' as mui;

import '../../core/zukko_chat_callbacks.dart';
import '../../core/zukko_chat_client.dart';
import '../../core/zukko_chat_upload.dart';
import '../../shared/sdk_log.dart';
import '../l10n/zukko_chat_l10n.dart';
import '../theme/zukko_chat_theme.dart';
import 'chat_attachment_flow.dart';
import 'chat_connection_banner.dart';
import 'chat_error_banner.dart';
import 'chat_header.dart';
import 'chat_message_list.dart';
import 'components/components.dart';
import 'zukko_chat_controller.dart';
import 'zukko_chat_options.dart';
import 'zukko_chat_style.dart';

export 'chat_header.dart' show ChatViewHeader;

/// Test seam, not exported: replaces `ZukkoChatClient.create` in the widget
/// tests. Null in production.
@visibleForTesting
ZukkoChatClientFactory? debugClientFactory;

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

  const ZukkoChatView({
    super.key,
    required this.options,
    this.callbacks,
    this.header,
    this.interactions = const ZukkoChatInteractions(),
  });

  @override
  State<ZukkoChatView> createState() => _ZukkoChatViewState();
}

/// What depends on the style, theme, strings and controller; rebuilt only
/// when one of them changes, not on every build.
class _Resolved {
  final ZukkoChatStyle styleKind;
  final ZukkoChatTheme theme;
  final ZukkoChatL10n l10n;
  final DateFormat? timeFormat;
  final ZukkoChatController controller;
  final ChatStyle style;
  final ChatMessageEnv env;
  final Builders builders;
  final mui.ThemeData muiTheme;

  const _Resolved({
    required this.styleKind,
    required this.theme,
    required this.l10n,
    required this.timeFormat,
    required this.controller,
    required this.style,
    required this.env,
    required this.builders,
    required this.muiTheme,
  });

  bool matches(
    ZukkoChatStyle styleKind,
    ZukkoChatTheme theme,
    ZukkoChatL10n l10n,
    DateFormat? timeFormat,
    ZukkoChatController controller,
  ) =>
      this.styleKind == styleKind &&
      this.theme == theme &&
      this.l10n == l10n &&
      this.timeFormat == timeFormat &&
      identical(this.controller, controller);
}

class _ZukkoChatViewState extends State<ZukkoChatView>
    with WidgetsBindingObserver {
  late ZukkoChatController _controller = _createController();
  final _audio = AudioPlaybackController();
  late final _defaultTimeFormat = DateFormat.Hm();
  ZukkoChatL10n _l10n = const ZukkoChatL10n();
  _Resolved? _resolved;

  /// Rebuilt when the composer-related options change (see [_composerData]).
  ChatComposerData? _composer;
  ({bool attach, bool voice})? _composerKey;

  /// Whether the inbox allows voice messages, once the session is known.
  bool _serverAllowsAudio = true;

  ZukkoChatController _createController() {
    final factory = debugClientFactory ?? ZukkoChatClient.create;
    late final ZukkoChatController controller;
    controller = ZukkoChatController(
      widget.options,
      callbacks: widget.callbacks,
      clientFactory:
          ({
            required baseUrl,
            required websiteToken,
            user,
            enablePersistence = true,
            callbacks,
          }) async {
            final client = await factory(
              baseUrl: baseUrl,
              websiteToken: websiteToken,
              user: user,
              enablePersistence: enablePersistence,
              callbacks: callbacks,
            );
            if (mounted && identical(controller, _controller)) {
              _adoptConfig(client);
            }
            return client;
          },
    );
    return controller;
  }

  /// The controller does not expose the client: read the inbox settings here.
  void _adoptConfig(ZukkoChatClient client) {
    var allows = true;
    try {
      allows = client.config?.audioMessagesEnabled ?? true;
    } catch (e) {
      // a custom client (demo, test) may not implement config
      sdkLog(
        'client config unavailable: ${e.runtimeType}',
        level: SdkLogLevel.warning,
      );
    }
    if (allows != _serverAllowsAudio) {
      setState(() => _serverAllowsAudio = allows);
    }
  }

  final _linkPreviews = LinkPreviewService();

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
    _resolve();
  }

  @override
  void didUpdateWidget(ZukkoChatView old) {
    super.didUpdateWidget(old);
    if (!widget.options.sameConnection(old.options)) {
      _controller.dispose();
      _serverAllowsAudio = true; // until the new session says otherwise
      _controller = _createController();
    } else {
      _controller.callbacks = widget.callbacks;
    }
    _syncL10n();
    _resolve();
  }

  /// Explicit strings, else the translation of the ambient locale.
  void _syncL10n() {
    _l10n =
        widget.options.l10n ??
        ZukkoChatL10n.forLocale(Localizations.maybeLocaleOf(context));
    _controller.l10n = _l10n;
  }

  void _resolve() {
    final o = widget.options;
    final theme = ZukkoChatTheme.resolve(context, o.theme);
    final current = _resolved;
    if (current != null &&
        current.matches(o.style, theme, _l10n, o.timeFormat, _controller)) {
      return;
    }
    final style = o.style.resolve(theme);
    final env = ChatMessageEnv(
      l10n: _l10n,
      timeFormat: o.timeFormat ?? _defaultTimeFormat,
      userById: _controller.userById,
      authorName: (id, isSentByMe) {
        if (isSentByMe) return _l10n.youLabel;
        final name = _controller.userById(id)?.name?.trim() ?? '';
        return name.isEmpty ? _l10n.headerTitle : name;
      },
      horizontalPadding: theme.horizontalPadding,
      audio: _audio,
    );
    _resolved = _Resolved(
      styleKind: o.style,
      theme: theme,
      l10n: _l10n,
      timeFormat: o.timeFormat,
      controller: _controller,
      style: style,
      env: env,
      builders: style.messageBuilders(env),
      muiTheme: ChatMessageList.muiThemeOf(style),
    );
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

  /// Closures read the current controller / widget when called, so one
  /// instance survives rebuilds and only changes with the option flags.
  ChatComposerData _composerData() {
    final o = widget.options;
    final key = (
      attach: o.enableAttachments,
      voice: o.enableVoiceMessages && _serverAllowsAudio,
    );
    if (_composerKey == key) return _composer!;
    _composerKey = key;
    return _composer = ChatComposerData(
      onSend: (text) {
        _controller.send(text);
        widget.interactions.onSendPressed?.call(text);
      },
      onTyping: () => _controller.typing(),
      onAttach: key.attach ? () => unawaited(_attach()) : null,
      onVoiceRecorded: key.voice
          ? (recording) => _controller.sendAttachments([
              recording.file,
            ], audioDuration: recording.duration)
          : null,
      onVoiceIssue: (issue) => _notify(voiceIssueText(_l10n, issue)),
      onTooLong: () =>
          _notify(_l10n.messageTooLong(ZukkoChatUpload.maxMessageLength)),
    );
  }

  Future<void> _attach() {
    final style = _resolved!.style;
    return attachToChat(
      context,
      controller: _controller,
      l10n: _l10n,
      spec: style.attachSheet,
      isMounted: () => mounted,
      notify: _notify,
    );
  }

  void _notify(String text) {
    if (mounted) showChatNotice(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    final r = _resolved!;
    final style = r.style;
    final header = widget.header;

    return LinkPreviewScope(
      service: o.enableLinkPreviews ? _linkPreviews : null,
      child: ColoredBox(
        color: style.backgroundColor,
        child: Column(
          children: [
            if (header != null)
              ChatHeader(
                controller: _controller,
                style: style,
                header: header,
                l10n: _l10n,
                onMore: widget.interactions.onMorePressed,
              ),
            ChatConnectionBanner(
              monitor: _controller.connection,
              l10n: _l10n,
              color: style.foregroundColor,
              horizontalPadding: r.theme.horizontalPadding,
            ),
            ChatErrorBanner(
              controller: _controller,
              l10n: _l10n,
              color: style.foregroundColor,
              horizontalPadding: r.theme.horizontalPadding,
            ),
            Expanded(
              child: ChatMessageList(
                controller: _controller,
                style: style,
                interactions: widget.interactions,
                env: r.env,
                builders: r.builders,
                muiTheme: r.muiTheme,
                onTap: _onTap,
              ),
            ),
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  style.buildComposer(context, _composerData(), _l10n),
                  style.buildFooter(context, _l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
