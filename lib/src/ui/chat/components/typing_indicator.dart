import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Three dots that fade in turn while the agent is typing. With "reduce
/// motion" on they stay still.
class TypingIndicator extends StatefulWidget {
  final Color color;
  final String semanticLabel;
  final double dotSize;

  const TypingIndicator({
    super.key,
    required this.color,
    required this.semanticLabel,
    this.dotSize = 6,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 1200);
  static const _dots = 3;
  static const _minOpacity = 0.35;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 0.35..1 opacity wave, each dot a third of a cycle behind the previous.
  double _opacity(int dot) {
    final phase = (_controller.value - dot / _dots) * 2 * math.pi;
    return _minOpacity + (1 - _minOpacity) * (0.5 + 0.5 * math.sin(phase));
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    liveRegion: true,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _dots; i++) ...[
              if (i > 0) SizedBox(width: widget.dotSize * 0.8),
              // Alpha in the color: no saveLayer per dot per frame.
              Container(
                width: widget.dotSize,
                height: widget.dotSize,
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: widget.color.a * _opacity(i),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
