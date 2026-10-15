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
class ChatMessageList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final i = interactions;
    final onLongPress = i.onMessageLongPress;
    final withList = builders.copyWith(
      chatAnimatedListBuilder: (context, itemBuilder) => ChatAnimatedList(
        itemBuilder: itemBuilder,
        onEndReached: i.onEndReached,
        paginationThreshold:
            i.onEndReachedThreshold ?? _defaultPaginationThreshold,
        handleSafeArea: false,
        bottomPadding: _bottomPadding,
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
      data: muiTheme,
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
            builders: withList,
          ),
        ),
      ),
    );
  }
}
