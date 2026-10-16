import 'package:flutter/material.dart';

import '../../../../l10n/zukko_chat_l10n.dart';
import '../../../components/components.dart';
import '../../../zukko_chat_style.dart';
import '../minimal_clean_metrics.dart';
import '../minimal_clean_tokens.dart';

/// Two-row card: the text on top, actions below (attach left; mic and send
/// right).
class MinimalCleanComposer extends StatelessWidget {
  final ChatComposerData data;
  final ZukkoChatL10n l10n;
  final MinimalCleanTokens tokens;
  final double horizontalPadding;

  const MinimalCleanComposer({
    super.key,
    required this.data,
    required this.l10n,
    required this.tokens,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) => ComposerShell(
    onSend: data.onSend,
    onTyping: data.onTyping,
    onVoiceRecorded: data.onVoiceRecorded,
    onVoiceIssue: data.onVoiceIssue,
    onTooLong: data.onTooLong,
    builder: (context, handle) => Padding(
      padding: composerInsets(
        horizontalPadding,
        shave: MinimalCleanMetrics.composerShave,
        top: MinimalCleanMetrics.composerTop,
        bottom: MinimalCleanMetrics.composerBottom,
      ),
      child: Container(
        padding: MinimalCleanMetrics.cardPadding,
        decoration: BoxDecoration(
          color: tokens.composerFill,
          borderRadius: BorderRadius.circular(
            MinimalCleanMetrics.composerRadius,
          ),
          border: Border.all(color: tokens.composerBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: MinimalCleanMetrics.inputPadding,
              child: ComposerInput(
                handle: handle,
                l10n: l10n,
                tokens: tokens,
                minHeight: MinimalCleanMetrics.inputMinHeight,
              ),
            ),
            Row(
              children: [
                ComposerAttachButton(
                  onAttach: data.onAttach,
                  handle: handle,
                  l10n: l10n,
                  tokens: tokens,
                  icon: Icons.add_rounded,
                  size: MinimalCleanMetrics.buttonSize,
                  hiddenWidth: 0,
                ),
                const Spacer(),
                ComposerMicButton(
                  handle: handle,
                  l10n: l10n,
                  tokens: tokens,
                  size: MinimalCleanMetrics.buttonSize,
                ),
                const SizedBox(width: MinimalCleanMetrics.actionGap),
                ComposerSendButton(
                  handle: handle,
                  l10n: l10n,
                  tokens: tokens,
                  size: MinimalCleanMetrics.buttonSize,
                  iconSize: MinimalCleanMetrics.sendIcon,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
