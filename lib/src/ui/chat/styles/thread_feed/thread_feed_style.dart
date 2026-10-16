import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../l10n/zukko_chat_l10n.dart';
import '../../../theme/zukko_chat_theme.dart';
import '../../components/components.dart';
import '../../zukko_chat_style.dart';
import '../shared/base_chat_style.dart';
import 'thread_feed_message_spec.dart';
import 'thread_feed_metrics.dart';
import 'thread_feed_attach_sheet.dart';
import 'thread_feed_tokens.dart';
import 'widgets/thread_feed_composer.dart';

/// Entry of the Thread Feed style.
class ThreadFeedStyle extends BaseChatStyle {
  final ThreadFeedTokens tokens;

  factory ThreadFeedStyle(ZukkoChatTheme theme) =>
      ThreadFeedStyle._(theme, ThreadFeedTokens.from(theme));

  ThreadFeedStyle._(ZukkoChatTheme theme, this.tokens)
    : super(
        theme: theme,
        base: tokens,
        surfaces: ChatSurfaces(
          container: tokens.fieldFill,
          containerLow: tokens.fieldFill,
          containerHigh: tokens.cardFill,
          radius: ThreadFeedMetrics.radius,
        ),
        footerFontSize: 11,
        footerLinkColor: tokens.link,
      );

  @override
  late final AttachSheetSpec attachSheet = threadFeedAttachSheet(tokens);

  @override
  late final MessageStyleSpec messageSpec = threadFeedMessageSpec(tokens);

  @override
  Widget buildHeader(
    BuildContext context,
    ChatHeaderData data,
    ZukkoChatL10n l10n,
  ) => ChatHeaderBar(
    title: data.title,
    status: data.status,
    isOnline: data.isOnline,
    onBack: data.onBack,
    onMore: data.onMore,
    l10n: l10n,
    look: HeaderBarLook(
      titleStyle: tokens.title,
      statusStyle: tokens.status,
      iconColor: tokens.text,
      moreIcon: Icons.more_vert_rounded,
      padding: ThreadFeedMetrics.headerPadding,
      buttonRadius: ThreadFeedMetrics.headerButtonRadius,
      onlineDot: tokens.online,
      avatar: HeaderAvatarLook(
        fill: tokens.agentAvatarFill,
        initialStyle: tokens.title.copyWith(color: tokens.agentAvatarText),
        radius: ThreadFeedMetrics.headerAvatarRadius,
      ),
    ),
  );

  @override
  Widget buildComposer(
    BuildContext context,
    ChatComposerData data,
    ZukkoChatL10n l10n,
  ) => ThreadFeedComposer(
    data: data,
    l10n: l10n,
    tokens: tokens,
    horizontalPadding: horizontalPadding,
  );

  @override
  Widget buildTypingIndicator(BuildContext context, ZukkoChatL10n l10n) =>
      TypingIndicatorRow(
        startInset:
            horizontalPadding +
            ThreadFeedMetrics.avatarSize +
            ThreadFeedMetrics.avatarGap,
        top: ThreadFeedMetrics.typingTop,
        bottom: ThreadFeedMetrics.typingBottom,
        dotColor: tokens.typingDot,
        label: l10n.typingText,
      );
}
