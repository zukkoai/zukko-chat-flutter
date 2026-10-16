import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../shared/format.dart';
import 'voice_recorder_controller.dart';

/// Wraps the microphone visual: long press records, sliding towards the
/// start edge by [cancelDistance] arms cancel, releasing sends.
///
/// Screen readers cannot hold and slide, so the node also has a tap action
/// that starts the recording and, when used again, sends it.
class VoiceRecordButton extends StatelessWidget {
  final VoiceRecorderController recorder;
  final String semanticLabel;
  final double cancelDistance;
  final Widget child;

  const VoiceRecordButton({
    super.key,
    required this.recorder,
    required this.semanticLabel,
    required this.child,
    this.cancelDistance = 72,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: semanticLabel,
      onTap: () => unawaited(recorder.toggle()),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => unawaited(recorder.start()),
        onLongPressMoveUpdate: (details) {
          final towardsStart = rtl
              ? details.offsetFromOrigin.dx
              : -details.offsetFromOrigin.dx;
          recorder.armCancel(towardsStart > cancelDistance);
        },
        onLongPressEnd: (_) => unawaited(recorder.finish()),
        onLongPressCancel: () => unawaited(recorder.cancel()),
        child: child,
      ),
    );
  }
}

/// Replaces the text field while recording: timer and the cancel hint.
class VoiceRecordingBar extends StatelessWidget {
  final VoiceRecorderController recorder;
  final String cancelHint;
  final String releaseToCancel;
  final TextStyle timerStyle;
  final TextStyle hintStyle;
  final Color dotColor;

  /// Announced to screen readers when the bar appears ("Recording...").
  final String? semanticLabel;

  const VoiceRecordingBar({
    super.key,
    required this.recorder,
    required this.cancelHint,
    required this.releaseToCancel,
    required this.timerStyle,
    required this.hintStyle,
    required this.dotColor,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hint = recorder.willCancel ? releaseToCancel : cancelHint;
    final label = semanticLabel;
    final row = Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          formatDuration(recorder.elapsed),
          style: timerStyle.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            hint,
            style: hintStyle,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    if (label == null) return row;
    // One live region: announced once on appear and when the hint changes,
    // not on every timer tick.
    return Semantics(
      liveRegion: true,
      label: '$label. $hint',
      excludeSemantics: true,
      child: row,
    );
  }
}
