import 'package:flutter/material.dart';

import '../../../../l10n/zukko_chat_l10n.dart';
import '../../../components/components.dart';
import '../../../zukko_chat_style.dart';
import '../thread_feed_metrics.dart';
import '../thread_feed_tokens.dart';

/// Square-cornered field (attach, text, send inside) and a separate
/// microphone tile, above a hairline.
class ThreadFeedComposer extends StatelessWidget {
  final ChatComposerData data;
  final ZukkoChatL10n l10n;
  final ThreadFeedTokens tokens;
  final double horizontalPadding;

  const ThreadFeedComposer({
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
    builder: (context, handle) => DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: Padding(
        padding: composerInsets(
          horizontalPadding,
          shave: ThreadFeedMetrics.composerShave,
          top: ThreadFeedMetrics.composerTop,
          bottom: ThreadFeedMetrics.composerBottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: ThreadFeedMetrics.composerHeight,
                ),
                padding: ThreadFeedMetrics.fieldPadding,
                decoration: BoxDecoration(
                  color: tokens.fieldFill,
                  borderRadius: BorderRadius.circular(ThreadFeedMetrics.radius),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ComposerAttachButton(
                      onAttach: data.onAttach,
                      handle: handle,
                      l10n: l10n,
                      tokens: tokens,
                      icon: Icons.attach_file_rounded,
                      radius: ThreadFeedMetrics.attachRadius,
                      size: ThreadFeedMetrics.attachSize,
                      hiddenWidth: ThreadFeedMetrics.hiddenAttachWidth,
                    ),
                    const SizedBox(width: ThreadFeedMetrics.attachGap),
                    Expanded(
                      child: ComposerInput(
                        handle: handle,
                        l10n: l10n,
                        tokens: tokens,
                        minHeight: ThreadFeedMetrics.inputMinHeight,
                      ),
                    ),
                    const SizedBox(width: ThreadFeedMetrics.sendGap),
                    ComposerSendButton(
                      handle: handle,
                      l10n: l10n,
                      tokens: tokens,
                      radius: ThreadFeedMetrics.sendRadius,
                      size: ThreadFeedMetrics.sendSize,
                      iconSize: ThreadFeedMetrics.sendIcon,
                    ),
                  ],
                ),
              ),
            ),
            if (handle.recorder != null) ...[
              const SizedBox(width: ThreadFeedMetrics.micGap),
              ComposerMicButton(
                handle: handle,
                l10n: l10n,
                tokens: tokens,
                size: ThreadFeedMetrics.composerHeight,
                tile: ComposerMicTile(
                  fill: tokens.micFill,
                  iconColor: tokens.micIcon,
                  radius: ThreadFeedMetrics.radius,
                  size: ThreadFeedMetrics.composerHeight,
                  iconSize: ThreadFeedMetrics.micIcon,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
