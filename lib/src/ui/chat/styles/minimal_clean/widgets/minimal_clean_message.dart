import 'package:flutter/widgets.dart';

import '../../../components/components.dart';
import '../minimal_clean_metrics.dart';
import '../minimal_clean_tokens.dart';

/// The user's content in a soft bubble; the agent's sits on the background
/// as plain text. The time (last message of a group) or the failure hint
/// sits under it.
class MinimalCleanMessage extends StatelessWidget {
  final MinimalCleanTokens tokens;
  final MessageSlot slot;
  final Widget child;

  const MinimalCleanMessage({
    super.key,
    required this.tokens,
    required this.slot,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final meta = slot.meta;
    final sent = slot.isSentByMe;
    final content = SendingOpacity(meta: meta, child: child);
    // Media brings its own shape (and its caption its own bubble).
    final Widget body = sent && slot.part != MessagePart.media
        ? ChatBubble(
            color: tokens.outgoingBubble,
            radius: MinimalCleanMetrics.bubbleRadius,
            maxWidthFactor: MinimalCleanMetrics.userMaxWidthFactor,
            padding: _padding,
            child: content,
          )
        : ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.sizeOf(context).width *
                  (sent
                      ? MinimalCleanMetrics.userMaxWidthFactor
                      : MinimalCleanMetrics.agentMaxWidthFactor),
            ),
            child: content,
          );
    return Column(
      crossAxisAlignment: sent
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        if (meta.failed)
          Padding(
            padding: const EdgeInsets.only(top: MinimalCleanMetrics.metaTop),
            child: FailedHint(
              text: slot.failedHint,
              captionStyle: tokens.caption,
              color: tokens.error,
            ),
          )
        else if (meta.isGroupEnd && meta.time.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: MinimalCleanMetrics.metaTop),
            child: Text(meta.time, style: tokens.caption),
          ),
      ],
    );
  }

  EdgeInsetsGeometry get _padding => switch (slot.part) {
    MessagePart.text => MinimalCleanMetrics.bubblePadding,
    MessagePart.media => EdgeInsets.zero,
    MessagePart.file => MinimalCleanMetrics.filePadding,
    MessagePart.audio => MinimalCleanMetrics.audioPadding,
  };
}
