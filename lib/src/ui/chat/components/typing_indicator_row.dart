import 'package:flutter/widgets.dart';

import 'typing_indicator.dart';

/// The "agent is typing" row under the last message: three dots, optionally
/// inside a bubble, inset from the start edge.
class TypingIndicatorRow extends StatelessWidget {
  final double startInset;
  final double top;
  final double bottom;
  final Color dotColor;
  final String label;

  /// Draws the dots inside a bubble of this color.
  final Color? bubbleColor;
  final double bubbleRadius;
  final EdgeInsetsGeometry bubblePadding;

  const TypingIndicatorRow({
    super.key,
    required this.startInset,
    required this.top,
    required this.dotColor,
    required this.label,
    this.bottom = 0,
    this.bubbleColor,
    this.bubbleRadius = 0,
    this.bubblePadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final dots = TypingIndicator(color: dotColor, semanticLabel: label);
    final fill = bubbleColor;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: startInset,
        top: top,
        bottom: bottom,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: fill == null
            ? dots
            : Container(
                padding: bubblePadding,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(bubbleRadius),
                ),
                child: dots,
              ),
      ),
    );
  }
}
