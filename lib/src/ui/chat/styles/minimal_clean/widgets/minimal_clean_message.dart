import 'package:flutter/widgets.dart';

import '../../../components/message_meta.dart';
import '../minimal_clean_tokens.dart';

/// The user's content in a soft bubble; the agent's sits on the background
/// as plain text. No times: only a failure hint under a failed message.
class MinimalCleanMessage extends StatelessWidget {
  final MinimalCleanTokens tokens;
  final bool isSentByMe;
  final MessageMeta meta;
  final String failedHint;
  final Widget child;

  /// False for media that brings its own shape (images).
  final bool bubble;
  final EdgeInsetsGeometry padding;

  const MinimalCleanMessage({
    super.key,
    required this.tokens,
    required this.isSentByMe,
    required this.meta,
    required this.failedHint,
    required this.child,
    this.bubble = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final content = Opacity(opacity: meta.sending ? 0.6 : 1, child: child);
    final Widget body = isSentByMe && bubble
        ? Container(
            constraints: BoxConstraints(maxWidth: width * 0.72),
            padding: padding,
            decoration: BoxDecoration(
              color: tokens.outgoingBubble,
              borderRadius: BorderRadius.circular(
                MinimalCleanTokens.bubbleRadius,
              ),
            ),
            child: content,
          )
        : ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width * (isSentByMe ? 0.72 : 0.9),
            ),
            child: content,
          );
    return Column(
      crossAxisAlignment: isSentByMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        if (meta.failed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              failedHint,
              style: tokens.caption.copyWith(color: tokens.error),
            ),
          ),
      ],
    );
  }
}
