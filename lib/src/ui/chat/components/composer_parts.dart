import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/zukko_chat_l10n.dart';
import '../../theme/chat_base_tokens.dart';
import 'components.dart';

/// Horizontal inset of a composer: the chat's gap minus [shave] (the
/// composer's own container already has padding), never negative.
EdgeInsets composerInsets(
  double horizontalPadding, {
  required double shave,
  required double top,
  required double bottom,
}) {
  final x = math.max(0.0, horizontalPadding - shave);
  return EdgeInsets.fromLTRB(x, top, x, bottom);
}

/// The slot of the text field. At least [minHeight] high, it grows with the
/// text scale instead of clipping.
class ComposerInput extends StatelessWidget {
  final ComposerHandle handle;
  final ZukkoChatL10n l10n;
  final ChatBaseTokens tokens;
  final double minHeight;

  const ComposerInput({
    super.key,
    required this.handle,
    required this.l10n,
    required this.tokens,
    required this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ComposerTextField(
      handle: handle,
      hintText: l10n.inputPlaceholder,
      style: tokens.body,
      hintStyle: tokens.hint,
      cursorColor: tokens.accent,
      keyboardAppearance: tokens.brightness,
    );
  }
}

/// Round or rounded-square send button: enabled while there is text.
class ComposerSendButton extends StatelessWidget {
  final ComposerHandle handle;
  final ZukkoChatL10n l10n;
  final ChatBaseTokens tokens;
  final double size;
  final double iconSize;
  final double? radius;

  const ComposerSendButton({
    super.key,
    required this.handle,
    required this.l10n,
    required this.tokens,
    required this.size,
    required this.iconSize,
    this.radius,
  });

  @override
  Widget build(BuildContext context) => ChatIconButton(
    icon: Icons.arrow_upward_rounded,
    tooltip: l10n.sendLabel,
    onPressed: handle.canSend ? handle.send : null,
    color: tokens.onAccent,
    fill: tokens.accent,
    radius: radius,
    size: size,
    iconSize: iconSize,
  );
}

/// Attach button. While recording (or without an attach callback) it gives
/// way to a [hiddenWidth] gap, so the layout does not jump.
class ComposerAttachButton extends StatelessWidget {
  final VoidCallback? onAttach;
  final ComposerHandle handle;
  final ZukkoChatL10n l10n;
  final ChatBaseTokens tokens;
  final IconData icon;
  final double size;
  final double hiddenWidth;
  final Color? fill;
  final double? radius;

  const ComposerAttachButton({
    super.key,
    required this.onAttach,
    required this.handle,
    required this.l10n,
    required this.tokens,
    required this.icon,
    required this.size,
    required this.hiddenWidth,
    this.fill,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (onAttach == null || handle.isRecording) {
      return SizedBox(width: hiddenWidth);
    }
    return ChatIconButton(
      icon: icon,
      tooltip: l10n.attachLabel,
      onPressed: onAttach,
      color: tokens.icon,
      fill: fill,
      radius: radius,
      size: size,
    );
  }
}

/// A filled tile behind the microphone (instead of a bare icon).
@immutable
class ComposerMicTile {
  final Color fill;
  final Color iconColor;
  final double radius;
  final double size;
  final double iconSize;

  const ComposerMicTile({
    required this.fill,
    required this.iconColor,
    required this.radius,
    required this.size,
    required this.iconSize,
  });
}

/// Hold-to-record microphone: a bare icon, or a [tile]. Nothing but an
/// [absentWidth] gap when voice messages are off.
class ComposerMicButton extends StatelessWidget {
  final ComposerHandle handle;
  final ZukkoChatL10n l10n;
  final ChatBaseTokens tokens;
  final double size;
  final double iconSize;
  final double absentWidth;
  final ComposerMicTile? tile;

  /// How the mic looks while recording; null keeps the plain accent look.
  final VoiceRecordingSpec? recording;

  const ComposerMicButton({
    super.key,
    required this.handle,
    required this.l10n,
    required this.tokens,
    required this.size,
    this.iconSize = 22,
    this.absentWidth = 0,
    this.tile,
    this.recording,
  });

  @override
  Widget build(BuildContext context) {
    final recorder = handle.recorder;
    if (recorder == null) return SizedBox(width: absentWidth);
    final isRecording = recorder.isRecording;
    final t = tile;
    final spec = recording;
    final Widget visual = isRecording && spec != null
        ? VoiceMicRecording(spec: spec)
        : t == null
        ? SizedBox.square(
            dimension: size,
            child: Icon(
              Icons.mic_none_rounded,
              size: iconSize,
              color: isRecording ? tokens.accent : tokens.icon,
            ),
          )
        : Container(
            width: t.size,
            height: t.size,
            decoration: BoxDecoration(
              color: isRecording ? tokens.accent : t.fill,
              borderRadius: BorderRadius.circular(t.radius),
            ),
            child: Icon(
              Icons.mic_none_rounded,
              size: t.iconSize,
              color: isRecording ? tokens.onAccent : t.iconColor,
            ),
          );
    return VoiceRecordButton(
      key: handle.micKey,
      recorder: recorder,
      semanticLabel: isRecording
          ? l10n.voiceRecordingButtonLabel
          : l10n.voiceRecordLabel,
      child: visual,
    );
  }
}
