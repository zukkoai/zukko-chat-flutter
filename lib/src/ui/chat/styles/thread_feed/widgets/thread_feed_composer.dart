import 'package:flutter/material.dart';

import '../../../../l10n/chatwoot_l10n.dart';
import '../../../chatwoot_chat_style.dart';
import '../../../components/chat_icon_button.dart';
import '../../../components/composer_shell.dart';
import '../../../components/voice_recorder.dart';
import '../thread_feed_tokens.dart';

/// Square-cornered field (attach, text, send inside) and a separate
/// microphone tile, above a hairline.
class ThreadFeedComposer extends StatelessWidget {
  final ChatComposerData data;
  final ChatwootL10n l10n;
  final ThreadFeedTokens tokens;
  final double horizontalPadding;

  const ThreadFeedComposer({
    super.key,
    required this.data,
    required this.l10n,
    required this.tokens,
    required this.horizontalPadding,
  });

  static const _height = 50.0;

  @override
  Widget build(BuildContext context) => ComposerShell(
    onSend: data.onSend,
    onVoiceRecorded: data.onVoiceRecorded,
    onVoiceIssue: data.onVoiceIssue,
    builder: (context, handle) {
      final recorder = handle.recorder;
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.divider)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding - 4,
            10,
            horizontalPadding - 4,
            4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: _height),
                  padding: const EdgeInsetsDirectional.fromSTEB(3, 3, 5, 3),
                  decoration: BoxDecoration(
                    color: tokens.fieldFill,
                    borderRadius: BorderRadius.circular(
                      ThreadFeedTokens.radius,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (data.onAttach != null && !handle.isRecording)
                        ChatIconButton(
                          icon: Icons.attach_file_rounded,
                          tooltip: l10n.attachLabel,
                          onPressed: data.onAttach,
                          color: tokens.icon,
                          radius: 10,
                          size: 44,
                        )
                      else
                        const SizedBox(width: 12),
                      const SizedBox(width: 2),
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
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ChatIconButton(
                          icon: Icons.arrow_upward_rounded,
                          tooltip: l10n.sendLabel,
                          onPressed: handle.canSend ? handle.send : null,
                          color: tokens.onAccent,
                          fill: tokens.accent,
                          radius: 9,
                          size: 40,
                          iconSize: 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (recorder != null) ...[
                const SizedBox(width: 8),
                VoiceRecordButton(
                  recorder: recorder,
                  semanticLabel: l10n.voiceRecordLabel,
                  child: Container(
                    width: _height,
                    height: _height,
                    decoration: BoxDecoration(
                      color: recorder.isRecording
                          ? tokens.accent
                          : tokens.micFill,
                      borderRadius: BorderRadius.circular(
                        ThreadFeedTokens.radius,
                      ),
                    ),
                    child: Icon(
                      Icons.mic_none_rounded,
                      size: 23,
                      color: recorder.isRecording
                          ? tokens.onAccent
                          : tokens.micIcon,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
