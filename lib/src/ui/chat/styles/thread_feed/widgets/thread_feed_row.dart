import 'package:flutter/widgets.dart';

import '../../../components/components.dart';
import '../thread_feed_metrics.dart';
import '../thread_feed_tokens.dart';

/// One full-width row: avatar, then name and time over the content. Later
/// messages of the same group keep the indent but skip avatar and name.
class ThreadFeedRow extends StatelessWidget {
  final ThreadFeedTokens tokens;
  final MessageSlot slot;
  final Widget child;

  const ThreadFeedRow({
    super.key,
    required this.tokens,
    required this.slot,
    required this.child,
  });

  /// Files and voice messages sit in a card; the rest is bare.
  Widget get _content => switch (slot.part) {
    MessagePart.file => _Card(
      padding: ThreadFeedMetrics.cardPadding,
      fill: tokens.cardFill,
      border: tokens.cardBorder,
      radius: ThreadFeedMetrics.radius,
      child: child,
    ),
    MessagePart.audio => _Card(
      padding: ThreadFeedMetrics.audioPadding,
      fill: tokens.fieldFill,
      radius: ThreadFeedMetrics.audioRadius,
      child: child,
    ),
    _ => child,
  };

  @override
  Widget build(BuildContext context) {
    final meta = slot.meta;
    final sent = slot.isSentByMe;
    final showAuthor = meta.isGroupStart;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAuthor)
          ChatAvatar(
            name: slot.authorName,
            imageUrl: slot.avatarUrl,
            size: ThreadFeedMetrics.avatarSize,
            radius: sent ? null : ThreadFeedMetrics.rowAvatarRadius,
            background: sent ? tokens.userAvatarFill : tokens.agentAvatarFill,
            initialStyle: tokens.name.copyWith(
              color: sent ? tokens.userAvatarText : tokens.agentAvatarText,
            ),
          )
        else
          const SizedBox(width: ThreadFeedMetrics.avatarSize),
        const SizedBox(width: ThreadFeedMetrics.avatarGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showAuthor)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: ThreadFeedMetrics.nameGap,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          slot.authorName,
                          style: tokens.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: ThreadFeedMetrics.timeGap),
                      Text(meta.time, style: tokens.caption),
                    ],
                  ),
                ),
              SendingOpacity(meta: meta, child: _content),
              if (meta.sending)
                Padding(
                  padding: const EdgeInsets.only(
                    top: ThreadFeedMetrics.failedHintTop,
                  ),
                  child: SendingMark(
                    label: slot.sendingLabel,
                    captionStyle: tokens.caption,
                  ),
                ),
              if (meta.failed)
                Padding(
                  padding: const EdgeInsets.only(
                    top: ThreadFeedMetrics.failedHintTop,
                  ),
                  child: FailedHint(
                    text: slot.failedHint,
                    captionStyle: tokens.caption,
                    color: tokens.error,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Color fill;
  final Color? border;
  final double radius;
  final Widget child;

  const _Card({
    required this.padding,
    required this.fill,
    required this.radius,
    required this.child,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final line = border;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: line == null ? null : Border.all(color: line),
      ),
      child: child,
    );
  }
}
