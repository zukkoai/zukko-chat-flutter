import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'audio_playback.dart';
import '../../../shared/format.dart';

/// Colors of an [AudioPlayerBar].
@immutable
class AudioPlayerColors {
  final Color buttonFill;
  final Color buttonIcon;
  final Color waveActive;
  final Color waveInactive;

  const AudioPlayerColors({
    required this.buttonFill,
    required this.buttonIcon,
    required this.waveActive,
    required this.waveInactive,
  });
}

/// Voice message: play / pause button, waveform with progress, duration.
/// Playback state comes from the chat's [AudioPlaybackController].
class AudioPlayerBar extends StatefulWidget {
  final AudioPlaybackController playback;
  final String source;

  /// Shown until the player knows the real length.
  final Duration duration;

  /// Bar heights in 0..1.
  final List<double> waveform;
  final AudioPlayerColors colors;
  final TextStyle durationStyle;
  final String semanticLabel;
  final String playLabel;
  final String pauseLabel;
  final double buttonSize;

  /// Corner radius of the button; null makes it a circle.
  final double? buttonRadius;

  const AudioPlayerBar({
    super.key,
    required this.playback,
    required this.source,
    required this.duration,
    required this.waveform,
    required this.colors,
    required this.durationStyle,
    required this.semanticLabel,
    required this.playLabel,
    required this.pauseLabel,
    this.buttonSize = 36,
    this.buttonRadius,
  });

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  /// Tap target of the play button (the visual is [buttonSize]).
  static const _tapSize = 48.0;
  static const _gap = 10.0;

  @override
  void didUpdateWidget(AudioPlayerBar old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) old.playback.release(old.source);
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    final source = widget.source;
    final duration = widget.duration;
    final colors = widget.colors;
    final buttonSize = widget.buttonSize;
    final buttonRadius = widget.buttonRadius;
    return ValueListenableBuilder<AudioPlaybackView>(
      valueListenable: playback.watch(source),
      builder: (context, view, _) {
        final playing = view.playing;
        final length = view.length ?? duration;
        final radius = buttonRadius;
        return Semantics(
          label: '${widget.semanticLabel}, ${formatDuration(length)}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: playing ? widget.pauseLabel : widget.playLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(playback.toggle(source)),
                  child: SizedBox.square(
                    dimension: math.max(_tapSize, buttonSize),
                    child: Center(
                      child: Container(
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          color: colors.buttonFill,
                          shape: radius == null
                              ? BoxShape.circle
                              : BoxShape.rectangle,
                          borderRadius: radius == null
                              ? null
                              : BorderRadius.circular(radius),
                        ),
                        child: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: buttonSize * 0.55,
                          color: colors.buttonIcon,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              Flexible(
                child: RepaintBoundary(
                  child: _SeekableWaveform(
                    samples: widget.waveform,
                    progress: view.progress,
                    colors: colors,
                    onSeek: (fraction) =>
                        unawaited(playback.seek(source, fraction)),
                  ),
                ),
              ),
              const SizedBox(width: _gap),
              ExcludeSemantics(
                child: Text(
                  formatDuration(length),
                  style: widget.durationStyle.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The waveform as a scrubber: tap or drag to jump. While dragging it
/// follows the finger and seeks once on release.
class _SeekableWaveform extends StatefulWidget {
  final List<double> samples;
  final double progress;
  final AudioPlayerColors colors;
  final ValueChanged<double> onSeek;

  const _SeekableWaveform({
    required this.samples,
    required this.progress,
    required this.colors,
    required this.onSeek,
  });

  @override
  State<_SeekableWaveform> createState() => _SeekableWaveformState();
}

class _SeekableWaveformState extends State<_SeekableWaveform> {
  /// Drawn width when there is room; it shrinks in a narrow bubble.
  static const _width = 140.0;
  static const _height = 26.0;
  static const _step = 0.1;

  /// Finger position while dragging, else null.
  double? _dragging;

  /// [dx] (from the left edge) as 0..1 of the drawn width, reading
  /// direction aware.
  double _fractionAt(double dx) {
    final width = context.size?.width ?? _width;
    if (width <= 0) return 0;
    final x = Directionality.of(context) == TextDirection.rtl ? width - dx : dx;
    return (x / width).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _dragging ?? widget.progress;
    return Semantics(
      slider: true,
      value: '${(progress * 100).round()}%',
      increasedValue: '${((progress + _step).clamp(0.0, 1.0) * 100).round()}%',
      decreasedValue: '${((progress - _step).clamp(0.0, 1.0) * 100).round()}%',
      onIncrease: () => widget.onSeek((progress + _step).clamp(0.0, 1.0)),
      onDecrease: () => widget.onSeek((progress - _step).clamp(0.0, 1.0)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => widget.onSeek(_fractionAt(d.localPosition.dx)),
        onHorizontalDragStart: (d) =>
            setState(() => _dragging = _fractionAt(d.localPosition.dx)),
        onHorizontalDragUpdate: (d) =>
            setState(() => _dragging = _fractionAt(d.localPosition.dx)),
        onHorizontalDragEnd: (_) {
          final target = _dragging;
          setState(() => _dragging = null);
          if (target != null) widget.onSeek(target);
        },
        onHorizontalDragCancel: () => setState(() => _dragging = null),
        child: SizedBox(
          height: _height,
          width: _width,
          child: CustomPaint(
            painter: _WaveformPainter(
              samples: widget.samples,
              progress: progress,
              active: widget.colors.waveActive,
              inactive: widget.colors.waveInactive,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final Color active;
  final Color inactive;

  _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.active,
    required this.inactive,
  });

  static const _barWidth = 3.0;
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final count = ((size.width + _gap) / (_barWidth + _gap)).floor();
    if (count <= 0) return;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _barWidth;
    final playedBars = (progress.clamp(0.0, 1.0) * count).round();
    for (var i = 0; i < count; i++) {
      final sample = samples[i * samples.length ~/ count]
          .clamp(0.15, 1.0)
          .toDouble();
      final h = sample * size.height;
      final x = i * (_barWidth + _gap) + _barWidth / 2;
      final top = (size.height - h) / 2;
      paint.color = i < playedBars ? active : inactive;
      canvas.drawLine(Offset(x, top), Offset(x, top + h), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.samples != samples ||
      old.progress != progress ||
      old.active != active ||
      old.inactive != inactive;
}

final _waveforms = <String, List<double>>{};
const _waveformCacheSize = 256;

/// Stable pseudo-waveform for a message without one (same [seed], same bars).
/// Cached: the same list instance comes back, so the painter sees no change.
List<double> placeholderWaveform(String seed, {int count = 32}) {
  final key = '$count|$seed';
  final cached = _waveforms[key];
  if (cached != null) return cached;
  if (_waveforms.length >= _waveformCacheSize) _waveforms.clear();
  var h = seed.codeUnits.fold<int>(17, (a, c) => (a * 31 + c) & 0x7fffffff);
  return _waveforms[key] = List<double>.unmodifiable(
    List<double>.generate(count, (_) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      return 0.25 + (h % 1000) / 1000 * 0.75;
    }),
  );
}
