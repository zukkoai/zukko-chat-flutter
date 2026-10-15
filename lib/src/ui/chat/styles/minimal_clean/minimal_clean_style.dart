import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../l10n/zukko_chat_l10n.dart';
import '../../../theme/zukko_chat_theme.dart';
import '../../components/components.dart';
import '../../zukko_chat_style.dart';
import '../shared/base_chat_style.dart';
import 'minimal_clean_message_spec.dart';
import 'minimal_clean_metrics.dart';
import 'minimal_clean_tokens.dart';
import 'widgets/minimal_clean_composer.dart';

/// Entry of the Minimal Clean style.
class MinimalCleanStyle extends BaseChatStyle {
  final MinimalCleanTokens tokens;

  factory MinimalCleanStyle(ZukkoChatTheme theme) =>
      MinimalCleanStyle._(theme, MinimalCleanTokens.from(theme));

  MinimalCleanStyle._(ZukkoChatTheme theme, this.tokens)
    : super(
        theme: theme,
        base: tokens,
        surfaces: ChatSurfaces(
          container: tokens.outgoingBubble,
          containerLow: tokens.composerFill,
          containerHigh: tokens.outgoingBubble,
          radius: MinimalCleanMetrics.bubbleRadius,
        ),
        footerFontSize: 11,
        footerLinkColor: tokens.accent,
      );

  @override
  late final MessageStyleSpec messageSpec = minimalCleanMessageSpec(tokens);

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
      moreIcon: Icons.more_horiz_rounded,
      padding: MinimalCleanMetrics.headerPadding,
      buttonRadius: MinimalCleanMetrics.headerButtonRadius,
      centered: true,
      divider: tokens.divider,
    ),
  );

  @override
  Widget buildComposer(
    BuildContext context,
    ChatComposerData data,
    ZukkoChatL10n l10n,
  ) => MinimalCleanComposer(
    data: data,
    l10n: l10n,
    tokens: tokens,
    horizontalPadding: horizontalPadding,
  );

  @override
  Widget buildTypingIndicator(BuildContext context, ZukkoChatL10n l10n) =>
      TypingIndicatorRow(
        startInset: horizontalPadding + MinimalCleanMetrics.typingStartExtra,
        top: MinimalCleanMetrics.typingTop,
        bottom: MinimalCleanMetrics.typingBottom,
        dotColor: tokens.typingDot,
        label: l10n.typingText,
      );
}
