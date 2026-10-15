import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Three dots that fade in turn while the agent is typing.
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 0.35..1 opacity wave, each dot a third of a cycle behind the previous.
  double _opacity(int dot) {
    final phase = (_controller.value - dot / 3) * 2 * math.pi;
    return 0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase));
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
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: widget.dotSize * 0.8),
              Opacity(
                opacity: _opacity(i),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
