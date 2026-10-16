import 'package:flutter/material.dart';

import '../../../../l10n/zukko_chat_l10n.dart';
import '../../../components/components.dart';
import '../../../zukko_chat_style.dart';
import '../smooth_silk_metrics.dart';
import '../smooth_silk_tokens.dart';

/// Pill field (attach, text, mic) on the background plus a round send button,
/// all in the chat's own tone.
class SmoothSilkComposer extends StatelessWidget {
  final ChatComposerData data;
  final ZukkoChatL10n l10n;
  final SmoothSilkTokens tokens;
  final double horizontalPadding;

  const SmoothSilkComposer({
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
        shave: SmoothSilkMetrics.composerShave,
        top: SmoothSilkMetrics.composerTop,
        bottom: SmoothSilkMetrics.composerBottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: SmoothSilkMetrics.composerHeight,
              ),
              padding: SmoothSilkMetrics.pillPadding,
              decoration: BoxDecoration(
                color: tokens.composerFill,
                borderRadius: BorderRadius.circular(
                  SmoothSilkMetrics.composerHeight / 2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ComposerAttachButton(
                    onAttach: data.onAttach,
                    handle: handle,
                    l10n: l10n,
                    tokens: tokens,
                    icon: Icons.add_rounded,
                    fill: tokens.composerButtonFill,
                    size: SmoothSilkMetrics.buttonSize,
                    hiddenWidth: SmoothSilkMetrics.hiddenAttachWidth,
                  ),
                  const SizedBox(width: SmoothSilkMetrics.attachGap),
                  Expanded(
                    child: ComposerInput(
                      handle: handle,
                      l10n: l10n,
                      tokens: tokens,
                      minHeight: SmoothSilkMetrics.inputMinHeight,
                    ),
                  ),
                  ComposerMicButton(
                    handle: handle,
                    l10n: l10n,
                    tokens: tokens,
                    size: SmoothSilkMetrics.buttonSize,
                    absentWidth: SmoothSilkMetrics.micAbsentWidth,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: SmoothSilkMetrics.sendGap),
          // Same circle as the attach button, and level with it.
          Padding(
            padding: EdgeInsets.only(
              bottom: SmoothSilkMetrics.pillPadding.bottom,
            ),
            child: ComposerSendButton(
              handle: handle,
              l10n: l10n,
              tokens: tokens,
              size: SmoothSilkMetrics.buttonSize,
              iconSize: SmoothSilkMetrics.sendIcon,
            ),
          ),
        ],
      ),
    ),
  );
}
