import 'package:flutter/widgets.dart';

import '../../../components/chat_avatar.dart';
import '../../../components/message_meta.dart';
import '../thread_feed_tokens.dart';

/// One full-width row: avatar, then name and time over the content. Later
/// messages of the same group keep the indent but skip avatar and name.
class ThreadFeedRow extends StatelessWidget {
  final ThreadFeedTokens tokens;
  final bool isSentByMe;
  final String authorName;
  final String? avatarUrl;
  final MessageMeta meta;
  final String failedHint;
  final Widget child;

  const ThreadFeedRow({
    super.key,
    required this.tokens,
    required this.isSentByMe,
    required this.authorName,
    required this.meta,
    required this.failedHint,
    required this.child,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final showAuthor = meta.isGroupStart;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAuthor)
          ChatAvatar(
            name: authorName,
            imageUrl: avatarUrl,
            size: ThreadFeedTokens.avatarSize,
            radius: isSentByMe ? null : 10,
            background: isSentByMe
                ? tokens.userAvatarFill
                : tokens.agentAvatarFill,
            initialStyle: tokens.name.copyWith(
              color: isSentByMe
                  ? tokens.userAvatarText
                  : tokens.agentAvatarText,
            ),
          )
        else
          const SizedBox(width: ThreadFeedTokens.avatarSize),
        const SizedBox(width: ThreadFeedTokens.avatarGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showAuthor)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          authorName,
                          style: tokens.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(meta.time, style: tokens.caption),
                    ],
                  ),
                ),
              Opacity(opacity: meta.sending ? 0.6 : 1, child: child),
              if (meta.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    failedHint,
                    style: tokens.caption.copyWith(color: tokens.error),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
