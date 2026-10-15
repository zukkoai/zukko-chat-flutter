import 'package:flutter/material.dart';

import '../../../../l10n/chatwoot_l10n.dart';
import '../../../chatwoot_chat_style.dart';
import '../../../components/chat_icon_button.dart';
import '../../../components/composer_shell.dart';
import '../../../components/voice_recorder.dart';
import '../minimal_clean_tokens.dart';

/// Two-row card: the text on top, actions below (attach left; mic and send
/// right).
class MinimalCleanComposer extends StatelessWidget {
  final ChatComposerData data;
  final ChatwootL10n l10n;
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
    builder: (context, handle) {
      final recorder = handle.recorder;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding - 4,
          6,
          horizontalPadding - 4,
          4,
        ),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: tokens.composerFill,
            borderRadius: BorderRadius.circular(
              MinimalCleanTokens.composerRadius,
            ),
            border: Border.all(color: tokens.composerBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
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
              Row(
                children: [
                  if (data.onAttach != null)
                    ChatIconButton(
                      icon: Icons.add_rounded,
                      tooltip: l10n.attachLabel,
                      onPressed: handle.isRecording ? null : data.onAttach,
                      color: tokens.icon,
                      size: 44,
                    ),
                  const Spacer(),
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
                    ),
                  const SizedBox(width: 4),
                  ChatIconButton(
                    icon: Icons.arrow_upward_rounded,
                    tooltip: l10n.sendLabel,
                    onPressed: handle.canSend ? handle.send : null,
                    color: tokens.onAccent,
                    fill: tokens.accent,
                    size: 44,
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
