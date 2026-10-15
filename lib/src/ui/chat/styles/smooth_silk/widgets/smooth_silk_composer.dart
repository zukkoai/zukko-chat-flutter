import 'package:flutter/material.dart';

import '../../../../l10n/chatwoot_l10n.dart';
import '../../../chatwoot_chat_style.dart';
import '../../../components/chat_icon_button.dart';
import '../../../components/composer_shell.dart';
import '../../../components/voice_recorder.dart';
import '../smooth_silk_tokens.dart';

/// Pill field (attach, text, mic) on the background plus a round send button,
/// all in the chat's own tone.
class SmoothSilkComposer extends StatelessWidget {
  final ChatComposerData data;
  final ChatwootL10n l10n;
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
    onVoiceRecorded: data.onVoiceRecorded,
    onVoiceIssue: data.onVoiceIssue,
    builder: (context, handle) {
      final recorder = handle.recorder;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding - 2,
          8,
          horizontalPadding - 2,
          6,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: SmoothSilkTokens.composerHeight,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                decoration: BoxDecoration(
                  color: tokens.composerFill,
                  borderRadius: BorderRadius.circular(
                    SmoothSilkTokens.composerHeight / 2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (data.onAttach != null && !handle.isRecording)
                      ChatIconButton(
                        icon: Icons.add_rounded,
                        tooltip: l10n.attachLabel,
                        onPressed: data.onAttach,
                        color: tokens.icon,
                        fill: tokens.composerButtonFill,
                        size: 44,
                      )
                    else
                      const SizedBox(width: 12),
                    const SizedBox(width: 6),
                    Expanded(
                      child: recorder != null && recorder.isRecording
                          ? SizedBox(
                              height: 44,
                              child: VoiceRecordingBar(
                                recorder: recorder,
                                cancelHint: l10n.voiceCancelHint,
                                releaseToCancel: l10n.voiceReleaseToCancel,
                                timerStyle: tokens.body,
                                hintStyle: tokens.status,
                                dotColor: tokens.error,
                              ),
                            )
                          : ComposerTextField(
                              handle: handle,
                              hintText: l10n.inputPlaceholder,
                              style: tokens.body,
                              hintStyle: tokens.hint,
                              cursorColor: tokens.accent,
                              keyboardAppearance: tokens.brightness,
                            ),
                    ),
                    if (recorder != null)
                      VoiceRecordButton(
                        recorder: recorder,
                        semanticLabel: l10n.voiceRecordLabel,
                        child: SizedBox.square(
                          dimension: 44,
                          child: Icon(
                            Icons.mic_none_rounded,
                            size: 22,
                            color: recorder.isRecording
                                ? tokens.accent
                                : tokens.icon,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ChatIconButton(
              icon: Icons.arrow_upward_rounded,
              tooltip: l10n.sendLabel,
              onPressed: handle.canSend ? handle.send : null,
              color: tokens.onAccent,
              fill: tokens.accent,
              size: SmoothSilkTokens.composerHeight,
              iconSize: 22,
            ),
          ],
        ),
      );
    },
  );
}
