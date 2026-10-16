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
    builder: (context, handle) => handle.isRecording
        ? _recording(handle)
        : Padding(
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

  VoiceRecordingSpec get _spec => VoiceRecordingSpec(
    dotColor: tokens.error,
    dotSize: SmoothSilkMetrics.recDot,
    timerStyle: tokens.bodyStrong,
    barColor: tokens.accent,
    barWidth: SmoothSilkMetrics.recBarWidth,
    barRadius: SmoothSilkMetrics.recBarRadius,
    barMaxHeight: SmoothSilkMetrics.recBarMax,
    barStripHeight: SmoothSilkMetrics.recBarStrip,
    hintStyle: tokens.status.copyWith(fontSize: SmoothSilkMetrics.recHintSize),
    hintColor: tokens.mutedText,
    chevronSize: SmoothSilkMetrics.recChevron,
    micColor: tokens.accent,
    micIconColor: tokens.onAccent,
    micSize: SmoothSilkMetrics.recMic,
    micRadius: SmoothSilkMetrics.recMic / 2,
    micIconSize: SmoothSilkMetrics.recMicIcon,
    halos: 2,
  );

  /// Hint above, then the recording pill and the big pulsing mic.
  Widget _recording(ComposerHandle handle) {
    final recorder = handle.recorder!;
    final spec = _spec;
    return Padding(
      padding: composerInsets(
        horizontalPadding,
        shave: SmoothSilkMetrics.composerShave,
        top: SmoothSilkMetrics.composerTop,
        bottom: SmoothSilkMetrics.composerBottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              bottom: SmoothSilkMetrics.recHintGap,
            ),
            child: VoiceCancelHint(
              recorder: recorder,
              spec: spec,
              hint: l10n.voiceSlideLeftToCancel,
              releaseHint: l10n.voiceReleaseToCancel,
              recordingLabel: l10n.voiceRecordingLabel,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: SmoothSilkMetrics.composerHeight,
                  ),
                  padding: SmoothSilkMetrics.recPillPadding,
                  decoration: BoxDecoration(
                    color: tokens.composerFill,
                    borderRadius: BorderRadius.circular(
                      SmoothSilkMetrics.composerHeight / 2,
                    ),
                  ),
                  child: VoiceRecordingField(recorder: recorder, spec: spec),
                ),
              ),
              const SizedBox(width: SmoothSilkMetrics.recMicGap),
              ComposerMicButton(
                handle: handle,
                l10n: l10n,
                tokens: tokens,
                size: SmoothSilkMetrics.recMic,
                recording: spec,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
