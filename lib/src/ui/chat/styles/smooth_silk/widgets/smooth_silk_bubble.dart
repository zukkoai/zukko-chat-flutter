import 'package:flutter/widgets.dart';

import '../../../components/components.dart';
import '../smooth_silk_metrics.dart';
import '../smooth_silk_tokens.dart';

/// Tonal bubble without border or shadow; the time (last of a group) or the
/// failure hint sits under it, outside the bubble.
class SmoothSilkBubble extends StatelessWidget {
  final SmoothSilkTokens tokens;
  final MessageSlot slot;
  final Widget child;

  const SmoothSilkBubble({
    super.key,
    required this.tokens,
    required this.slot,
    required this.child,
  });

  EdgeInsetsGeometry get _padding => switch (slot.part) {
    MessagePart.text => SmoothSilkMetrics.bubblePadding,
    MessagePart.media => EdgeInsets.zero,
    MessagePart.file => SmoothSilkMetrics.filePadding,
    MessagePart.audio => SmoothSilkMetrics.audioPadding,
  };

  @override
  Widget build(BuildContext context) {
    final meta = slot.meta;
    final line = meta.failed
        ? FailedHint(
            text: slot.failedHint,
            captionStyle: tokens.caption,
            color: tokens.error,
          )
        : meta.sending
        ? SendingMark(label: slot.sendingLabel, captionStyle: tokens.caption)
        : meta.isGroupEnd && meta.time.isNotEmpty
        ? Text(meta.time, style: tokens.caption)
        : null;
    return Column(
      crossAxisAlignment: slot.isSentByMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatBubble(
          color: slot.isSentByMe
              ? tokens.outgoingBubble
              : tokens.incomingBubble,
          radius: SmoothSilkMetrics.bubbleRadius,
          maxWidthFactor: SmoothSilkMetrics.maxWidthFactor,
          padding: _padding,
          clip: Clip.antiAlias,
          child: SendingOpacity(meta: meta, child: child),
        ),
        if (line != null)
          Padding(padding: SmoothSilkMetrics.metaPadding, child: line),
      ],
    );
  }
}
