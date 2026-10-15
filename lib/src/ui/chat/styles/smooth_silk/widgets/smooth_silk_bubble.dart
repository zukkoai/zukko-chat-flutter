import 'package:flutter/widgets.dart';

import '../../../components/message_meta.dart';
import '../smooth_silk_tokens.dart';

/// Tonal bubble without border or shadow; the time (last of a group) or the
/// failure hint sits under it, outside the bubble.
class SmoothSilkBubble extends StatelessWidget {
  final SmoothSilkTokens tokens;
  final bool isSentByMe;
  final MessageMeta meta;
  final String failedHint;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const SmoothSilkBubble({
    super.key,
    required this.tokens,
    required this.isSentByMe,
    required this.meta,
    required this.failedHint,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final line = meta.failed
        ? Text(failedHint, style: tokens.caption.copyWith(color: tokens.error))
        : meta.isGroupEnd && meta.time.isNotEmpty
        ? Text(meta.time, style: tokens.caption)
        : null;
    return Column(
      crossAxisAlignment: isSentByMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: padding,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isSentByMe ? tokens.outgoingBubble : tokens.incomingBubble,
            borderRadius: BorderRadius.circular(SmoothSilkTokens.bubbleRadius),
          ),
          child: Opacity(opacity: meta.sending ? 0.6 : 1, child: child),
        ),
        if (line != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: line,
          ),
      ],
    );
  }
}
