import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../shared/format.dart';
import 'voice_recorder_controller.dart';

/// What a style draws the recording state with (colors from its tokens,
/// sizes from the design).
@immutable
class VoiceRecordingSpec {
  final Color dotColor;
  final double dotSize;
  final TextStyle timerStyle;
  final double timerMinWidth;
  final Color barColor;
  final double barWidth;
  final double barRadius;

  /// Tallest a bar gets, and the height of the strip they live in.
  final double barMaxHeight;
  final double barStripHeight;
  final double fieldGap;
  final TextStyle hintStyle;
  final Color hintColor;
  final double chevronSize;
  final double chevronGap;
  final Color micColor;
  final Color micIconColor;
  final double micSize;
  final double micRadius;
  final double micIconSize;

  /// 1 or 2 rings pulsing behind the microphone.
  final int halos;

  const VoiceRecordingSpec({
    required this.dotColor,
    required this.dotSize,
    required this.timerStyle,
    required this.barColor,
    required this.barWidth,
    required this.barRadius,
    required this.barMaxHeight,
    required this.barStripHeight,
    required this.hintStyle,
    required this.hintColor,
    required this.chevronSize,
    required this.micColor,
    required this.micIconColor,
    required this.micSize,
    required this.micRadius,
    required this.micIconSize,
    this.timerMinWidth = 38,
    this.fieldGap = 12,
    this.chevronGap = 6,
    this.halos = 1,
  });
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Rebuilds [builder] every frame with a looping 0..1 value; a constant
/// [staticValue] (and no ticker) when the platform asks for reduced motion.
class _Looping extends StatefulWidget {
  final Duration duration;
  final bool reverse;
  final double initial;
  final double staticValue;
  final Widget Function(BuildContext context, double value) builder;

  const _Looping({
    required this.duration,
    required this.builder,
    this.reverse = false,
    this.initial = 0,
    this.staticValue = 0,
  });

  @override
  State<_Looping> createState() => _LoopingState();
}

class _LoopingState extends State<_Looping>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.initial,
  );
  bool? _running;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = !_reduceMotion(context);
    if (run == _running) return;
    _running = run;
    if (run) {
      _ctl.repeat(reverse: widget.reverse);
    } else {
      _ctl.stop();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(_running ?? false)) {
      return widget.builder(context, widget.staticValue);
    }
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) => widget.builder(context, _ctl.value),
    );
  }
}

/// The recording field's content: blinking dot, timer, live level bars.
/// Put it inside the style's own container (pill, card row, field).
class VoiceRecordingField extends StatelessWidget {
  final VoiceRecorderController recorder;
  final VoiceRecordingSpec spec;

  const VoiceRecordingField({
    super.key,
    required this.recorder,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ExcludeSemantics(
        child: _Looping(
          duration: const Duration(milliseconds: 550),
          reverse: true,
          staticValue: 0,
          builder: (context, v) => Opacity(
            opacity: 1 - 0.75 * Curves.easeInOut.transform(v),
            child: Container(
              key: const ValueKey('voice-dot'),
              width: spec.dotSize,
              height: spec.dotSize,
              decoration: BoxDecoration(
                color: spec.dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
      SizedBox(width: spec.fieldGap),
      ConstrainedBox(
        constraints: BoxConstraints(minWidth: spec.timerMinWidth),
        // Not a live region: the screen reader reads it on focus, it does
        // not announce every second.
        child: ListenableBuilder(
          listenable: recorder,
          builder: (context, _) => Text(
            formatDuration(recorder.elapsed),
            key: const ValueKey('voice-timer'),
            style: spec.timerStyle.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
      SizedBox(width: spec.fieldGap),
      Expanded(
        child: ExcludeSemantics(
          child: SizedBox(
            height: spec.barStripHeight,
            child: _LevelBars(level: recorder.level, spec: spec),
          ),
        ),
      ),
    ],
  );
}

class _LevelBars extends StatelessWidget {
  final ValueListenable<double> level;
  final VoiceRecordingSpec spec;

  const _LevelBars({required this.level, required this.spec});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: _Looping(
      duration: _LevelPainter.period,
      staticValue: 0.25,
      builder: (context, t) => ValueListenableBuilder<double>(
        valueListenable: level,
        builder: (context, value, _) => CustomPaint(
          key: const ValueKey('voice-bars'),
          size: Size.infinite,
          painter: _LevelPainter(
            t: t,
            moving: !_reduceMotion(context),
            level: value,
            spec: spec,
          ),
        ),
      ),
    ),
  );
}

class _LevelPainter extends CustomPainter {
  static const period = Duration(milliseconds: 1800);
  static const _gap = 3.0;

  final double t;
  final bool moving;
  final double level;
  final VoiceRecordingSpec spec;

  _LevelPainter({
    required this.t,
    required this.moving,
    required this.level,
    required this.spec,
  });

  /// The design's static bar profile.
  static double _profile(int i, double max) =>
      6 + (math.sin(i * 1.7) * math.cos(i * 0.45)).abs() * (max - 6);

  /// The design's `level` keyframes (.25 -> 1 -> .35), alternating.
  static double _wave(int i, double t) {
    final delay = (i * 0.137) % 0.9;
    var local = (t * 1.8 - delay) % 1.8;
    if (local < 0) local += 1.8;
    final p = local < 0.9 ? local / 0.9 : 1 - (local - 0.9) / 0.9;
    return p < 0.5
        ? 0.25 + 0.75 * Curves.easeInOut.transform(p / 0.5)
        : 1 - 0.65 * Curves.easeInOut.transform((p - 0.5) / 0.5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = spec.barColor;
    // Quiet room: the bars still breathe a little; loud: full height.
    final amp = 0.35 + 0.65 * level;
    var i = 0;
    for (
      var x = 0.0;
      x + spec.barWidth <= size.width;
      x += spec.barWidth + _gap, i++
    ) {
      final wave = moving ? _wave(i, t) : 1.0;
      final h = math
          .max(3.0, _profile(i, spec.barMaxHeight) * wave * amp)
          .clamp(0.0, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, spec.barWidth, h),
          Radius.circular(spec.barRadius),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelPainter old) =>
      old.t != t || old.level != level || old.spec != spec;
}

/// "< Slide to cancel": a chevron that nudges to the start edge, then the
/// hint. Announced once when it appears and when it turns into "release".
class VoiceCancelHint extends StatelessWidget {
  final VoiceRecorderController recorder;
  final VoiceRecordingSpec spec;
  final String hint;
  final String releaseHint;

  /// "Recording voice message", announced with the hint.
  final String recordingLabel;
  final bool expand;

  const VoiceCancelHint({
    super.key,
    required this.recorder,
    required this.spec,
    required this.hint,
    required this.releaseHint,
    required this.recordingLabel,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final text = recorder.willCancel ? releaseHint : hint;
        return Semantics(
          liveRegion: true,
          label: '$recordingLabel. $text',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _Looping(
                duration: const Duration(milliseconds: 700),
                reverse: true,
                builder: (context, v) => Transform.translate(
                  offset: Offset(
                    (rtl ? 1 : -1) * 5 * Curves.easeInOut.transform(v),
                    0,
                  ),
                  child: Icon(
                    rtl
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    size: spec.chevronSize,
                    color: spec.hintColor,
                  ),
                ),
              ),
              SizedBox(width: spec.chevronGap),
              Flexible(
                child: Text(
                  text,
                  style: spec.hintStyle.copyWith(color: spec.hintColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The filled microphone shown while recording, with pulsing rings.
class VoiceMicRecording extends StatelessWidget {
  final VoiceRecordingSpec spec;

  const VoiceMicRecording({super.key, required this.spec});

  Widget _ring(double initial) => _Looping(
    duration: const Duration(milliseconds: 1600),
    initial: initial,
    staticValue: 0,
    builder: (context, v) {
      if (_reduceMotion(context)) return const SizedBox.shrink();
      final e = Curves.easeOut.transform(v);
      return Transform.scale(
        scale: 1 + 0.85 * e,
        child: Opacity(
          opacity: 0.5 * (1 - e),
          child: Container(
            decoration: BoxDecoration(
              color: spec.micColor,
              borderRadius: BorderRadius.circular(spec.micRadius),
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: spec.micSize,
    child: Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        // ponytail: the second ring is a half-period phase shift of the first.
        for (var i = 0; i < spec.halos; i++)
          Positioned.fill(child: IgnorePointer(child: _ring(i * 0.5))),
        DecoratedBox(
          decoration: BoxDecoration(
            color: spec.micColor,
            borderRadius: BorderRadius.circular(spec.micRadius),
          ),
          child: Center(
            child: Icon(
              Icons.mic_none_rounded,
              size: spec.micIconSize,
              color: spec.micIconColor,
            ),
          ),
        ),
      ],
    ),
  );
}
