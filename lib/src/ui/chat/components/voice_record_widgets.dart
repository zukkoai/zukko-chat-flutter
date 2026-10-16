import 'dart:async';

import 'package:flutter/widgets.dart';

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
