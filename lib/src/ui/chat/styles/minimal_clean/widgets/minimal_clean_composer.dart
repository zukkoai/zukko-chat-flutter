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
    builder: (context, handle) => handle.isRecording
        ? _recording(handle)
        : Padding(
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

  VoiceRecordingSpec get _spec => VoiceRecordingSpec(
    dotColor: tokens.error,
    dotSize: MinimalCleanMetrics.recDot,
    timerStyle: tokens.body.copyWith(fontWeight: FontWeight.w500),
    barColor: tokens.accent,
    barWidth: MinimalCleanMetrics.recBarWidth,
    barRadius: MinimalCleanMetrics.recBarRadius,
    barMaxHeight: MinimalCleanMetrics.recBarMax,
    barStripHeight: MinimalCleanMetrics.recBarStrip,
    hintStyle: tokens.status.copyWith(
      fontSize: MinimalCleanMetrics.recHintSize,
    ),
    hintColor: tokens.mutedText,
    chevronSize: MinimalCleanMetrics.recChevron,
    chevronGap: MinimalCleanMetrics.recChevronGap,
    micColor: tokens.accent,
    micIconColor: tokens.onAccent,
    micSize: MinimalCleanMetrics.recMic,
    micRadius: MinimalCleanMetrics.recMic / 2,
    micIconSize: MinimalCleanMetrics.recMicIcon,
  );

  /// Timer row on top, then the hint and the pulsing mic, inside the card.
  Widget _recording(ComposerHandle handle) {
    final recorder = handle.recorder!;
    final spec = _spec;
    return Padding(
      padding: composerInsets(
        horizontalPadding,
        shave: MinimalCleanMetrics.composerShave,
        top: MinimalCleanMetrics.composerTop,
        bottom: MinimalCleanMetrics.composerBottom,
      ),
      child: Container(
        padding: MinimalCleanMetrics.recCardPadding,
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
            Container(
              constraints: const BoxConstraints(
                minHeight: MinimalCleanMetrics.recRowHeight,
              ),
              padding: MinimalCleanMetrics.recRowPadding,
              child: VoiceRecordingField(recorder: recorder, spec: spec),
            ),
            const SizedBox(height: MinimalCleanMetrics.recRowGap),
            Padding(
              padding: MinimalCleanMetrics.recActionPadding,
              child: Row(
                children: [
                  Expanded(
                    child: VoiceCancelHint(
                      recorder: recorder,
                      spec: spec,
                      hint: l10n.voiceCancelHint,
                      releaseHint: l10n.voiceReleaseToCancel,
                      recordingLabel: l10n.voiceRecordingLabel,
                      expand: true,
                    ),
                  ),
                  ComposerMicButton(
                    handle: handle,
                    l10n: l10n,
                    tokens: tokens,
                    size: MinimalCleanMetrics.recMic,
                    recording: spec,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
