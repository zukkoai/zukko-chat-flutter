import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:material_ui/material_ui.dart' as mui;

import 'zukko_chat_controller.dart';
import 'zukko_chat_options.dart';
import 'zukko_chat_style.dart';

/// The flutter_chat_ui list with the style's message builders. The composer
/// is drawn by the view below the list, so the list's own one is empty.
///
/// [muiTheme] and [builders] are expensive to build, so the view creates
/// them once per style / theme / strings and passes them in.
///
/// Auto-scroll is done here, not by flutter_chat_ui: its own logic stops
/// following new messages for good once the user has dragged up at all
/// (`_userHasScrolled`), so a reply never showed after a small scroll up.
/// Here the user's own messages always scroll to the end; an incoming message
/// (or the typing indicator) does when the list was within one viewport of
/// the end, so a far-up history reader is not pulled down.
class ChatMessageList extends StatefulWidget {
  /// Default of [ZukkoChatInteractions.onEndReachedThreshold].
  static const _defaultPaginationThreshold = 0.01;
  static const _bottomPadding = 12.0;

  final ZukkoChatController controller;
  final ChatStyle style;
  final ZukkoChatInteractions interactions;
  final ChatMessageEnv env;
  final Builders builders;
  final mui.ThemeData muiTheme;
  final OnMessageTapCallback onTap;

  const ChatMessageList({
    super.key,
    required this.controller,
    required this.style,
    required this.interactions,
    required this.env,
    required this.builders,
    required this.muiTheme,
    required this.onTap,
  });

  /// flutter_chat_ui draws with material_ui, a separate widget set from
  /// flutter/material: it needs its own Theme ancestor.
  static mui.ThemeData muiThemeOf(ChatStyle style) => mui.ThemeData(
    colorScheme: mui.ColorScheme.fromSeed(
      seedColor: style.accentColor,
      brightness: style.brightness,
    ),
  );

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final _scroll = ScrollController();
  StreamSubscription<ChatOperation>? _ops;
  bool _typing = false;

  ZukkoChatController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(ChatMessageList old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _detach(old.controller);
      _attach();
    }
  }

  void _attach() {
    _typing = false;
    _ops = _controller.chat.operationsStream.listen((op) {
      final m = op.message;
      if (op.type == ChatOperationType.insert && m != null) {
        _followEnd(force: m.authorId == _controller.currentUserId);
      }
    });
    _controller.addListener(_onController);
  }

  void _onController() {
    final typing = _controller.status == ZukkoChatStatus.typing;
    if (typing && !_typing) _followEnd();
    _typing = typing;
  }

  void _detach(ZukkoChatController c) {
    c.removeListener(_onController);
    _ops?.cancel();
  }

  @override
  void dispose() {
    _detach(_controller);
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls to the end after the next layout when [force] or the list is
  /// within one viewport of the end (measured now, before the new item
  /// grows it). Loading older pages is not an insert, so it never gets here.
  void _followEnd({bool force = false}) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (!force && p.maxScrollExtent - p.pixels > p.viewportDimension) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.linearToEaseOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final style = widget.style;
    final env = widget.env;
    final i = widget.interactions;
    final onLongPress = i.onMessageLongPress;
    final withList = widget.builders.copyWith(
      chatAnimatedListBuilder: (context, itemBuilder) => ChatAnimatedList(
        itemBuilder: itemBuilder,
        scrollController: _scroll,
        shouldScrollToEndWhenSendingMessage: false,
        shouldScrollToEndWhenAtBottom: false,
        onEndReached: () async {
          await controller.loadOlder();
          await i.onEndReached?.call();
        },
        paginationThreshold:
            i.onEndReachedThreshold ??
            ChatMessageList._defaultPaginationThreshold,
        handleSafeArea: false,
        bottomPadding: ChatMessageList._bottomPadding,
        bottomSliver: SliverToBoxAdapter(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.status == ZukkoChatStatus.typing
                ? style.buildTypingIndicator(context, env.l10n)
                : const SizedBox.shrink(),
          ),
        ),
      ),
      composerBuilder: (context) => const SizedBox.shrink(),
    );
    // Its own Material too, and the English strings of material_ui when the
    // app only provides flutter/material localizations.
    return mui.Theme(
      data: widget.muiTheme,
      child: Localizations.override(
        context: context,
        delegates: [mui.DefaultMaterialLocalizations.delegate],
        child: mui.Material(
          type: mui.MaterialType.transparency,
          child: Chat(
            key: ObjectKey(controller.chat),
            currentUserId: controller.currentUserId,
            resolveUser: controller.resolveUser,
            chatController: controller.chat,
            onMessageTap: widget.onTap,
            onMessageLongPress: onLongPress == null
                ? null
                : (context, message, {required index, required details}) =>
                      onLongPress(context, message),
            timeFormat: env.timeFormat,
            theme: style.chatTheme,
            backgroundColor: style.backgroundColor,
            builders: withList,
          ),
        ),
      ),
    );
  }
}
