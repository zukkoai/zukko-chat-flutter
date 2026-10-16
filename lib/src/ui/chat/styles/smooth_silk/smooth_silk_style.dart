import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../l10n/zukko_chat_l10n.dart';
import '../../../theme/zukko_chat_theme.dart';
import '../../components/components.dart';
import '../../zukko_chat_style.dart';
import '../shared/base_chat_style.dart';
import 'smooth_silk_message_spec.dart';
import 'smooth_silk_metrics.dart';
import 'smooth_silk_attach_sheet.dart';
import 'smooth_silk_tokens.dart';
import 'widgets/smooth_silk_composer.dart';

/// Entry of the Smooth Silk style.
class SmoothSilkStyle extends BaseChatStyle {
  final SmoothSilkTokens tokens;

  factory SmoothSilkStyle(ZukkoChatTheme theme) =>
      SmoothSilkStyle._(theme, SmoothSilkTokens.from(theme));

  SmoothSilkStyle._(ZukkoChatTheme theme, this.tokens)
    : super(
        theme: theme,
        base: tokens,
        surfaces: ChatSurfaces(
          container: tokens.incomingBubble,
          containerLow: tokens.composerFill,
          containerHigh: tokens.outgoingBubble,
          radius: SmoothSilkMetrics.bubbleRadius,
        ),
        footerLinkColor: tokens.accent,
      );

  @override
  late final AttachSheetSpec attachSheet = smoothSilkAttachSheet(tokens);

  @override
  late final MessageStyleSpec messageSpec = smoothSilkMessageSpec(tokens);

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
      padding: SmoothSilkMetrics.headerPadding,
      avatar: HeaderAvatarLook(
        fill: tokens.avatarFill,
        initialStyle: tokens.title.copyWith(color: tokens.avatarText),
      ),
    ),
  );

  @override
  Widget buildComposer(
    BuildContext context,
    ChatComposerData data,
    ZukkoChatL10n l10n,
  ) => SmoothSilkComposer(
    data: data,
    l10n: l10n,
    tokens: tokens,
    horizontalPadding: horizontalPadding,
  );

  @override
  Widget buildTypingIndicator(BuildContext context, ZukkoChatL10n l10n) =>
      TypingIndicatorRow(
        startInset: horizontalPadding,
        top: SmoothSilkMetrics.typingTop,
        dotColor: tokens.typingDot,
        label: l10n.typingText,
        bubbleColor: tokens.incomingBubble,
        bubbleRadius: SmoothSilkMetrics.bubbleRadius,
        bubblePadding: SmoothSilkMetrics.typingPadding,
      );
}
