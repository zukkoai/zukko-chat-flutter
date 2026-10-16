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
    builder: (context, handle) => handle.isRecording
        ? _recording(handle)
        : DecoratedBox(
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
                        borderRadius: BorderRadius.circular(
                          ThreadFeedMetrics.radius,
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

  VoiceRecordingSpec get _spec => VoiceRecordingSpec(
    dotColor: tokens.error,
    dotSize: ThreadFeedMetrics.recDot,
    timerStyle: tokens.bodyStrong,
    barColor: tokens.accent,
    barWidth: ThreadFeedMetrics.recBarWidth,
    barRadius: ThreadFeedMetrics.recBarRadius,
    barMaxHeight: ThreadFeedMetrics.recBarMax,
    barStripHeight: ThreadFeedMetrics.recBarStrip,
    hintStyle: tokens.status.copyWith(fontSize: ThreadFeedMetrics.recHintSize),
    hintColor: tokens.mutedText,
    chevronSize: ThreadFeedMetrics.recChevron,
    micColor: tokens.accent,
    micIconColor: tokens.onAccent,
    micSize: ThreadFeedMetrics.recMic,
    micRadius: ThreadFeedMetrics.radius,
    micIconSize: ThreadFeedMetrics.recMicIcon,
  );

  /// Hint row, then the recording field and the pulsing mic tile.
  Widget _recording(ComposerHandle handle) {
    final recorder = handle.recorder!;
    final spec = _spec;
    return DecoratedBox(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: ThreadFeedMetrics.recHintPadding,
              child: VoiceCancelHint(
                recorder: recorder,
                spec: spec,
                hint: l10n.voiceSlideLeftToCancel,
                releaseHint: l10n.voiceReleaseToCancel,
                recordingLabel: l10n.voiceRecordingLabel,
              ),
            ),
            const SizedBox(height: ThreadFeedMetrics.recHintGap),
            Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: ThreadFeedMetrics.composerHeight,
                    ),
                    padding: ThreadFeedMetrics.recFieldPadding,
                    decoration: BoxDecoration(
                      color: tokens.fieldFill,
                      borderRadius: BorderRadius.circular(
                        ThreadFeedMetrics.radius,
                      ),
                    ),
                    child: VoiceRecordingField(recorder: recorder, spec: spec),
                  ),
                ),
                const SizedBox(width: ThreadFeedMetrics.micGap),
                ComposerMicButton(
                  handle: handle,
                  l10n: l10n,
                  tokens: tokens,
                  size: ThreadFeedMetrics.recMic,
                  recording: spec,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
