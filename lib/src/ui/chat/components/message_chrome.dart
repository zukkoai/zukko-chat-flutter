import 'package:flutter/widgets.dart';

import 'message_meta.dart';

/// Opacity of a message that is still being sent.
const kSendingOpacity = 0.6;

/// Dims [child] while the message is being sent.
class SendingOpacity extends StatelessWidget {
  final MessageMeta meta;
  final Widget child;

  const SendingOpacity({super.key, required this.meta, required this.child});

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: meta.sending ? kSendingOpacity : 1, child: child);
}

/// The "failed to send" line under a message; announced to screen readers.
class FailedHint extends StatelessWidget {
  final String text;
  final TextStyle captionStyle;
  final Color color;

  const FailedHint({
    super.key,
    required this.text,
    required this.captionStyle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(text, style: captionStyle.copyWith(color: color)),
  );
}

/// A filled rounded container for a message, at most [maxWidthFactor] of the
/// screen wide (unbounded when null).
class ChatBubble extends StatelessWidget {
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double? maxWidthFactor;
  final Clip clip;
  final Widget child;

  const ChatBubble({
    super.key,
    required this.color,
    required this.radius,
    required this.padding,
    required this.child,
    this.maxWidthFactor,
    this.clip = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final factor = maxWidthFactor;
    return Container(
      constraints: factor == null
          ? null
          : BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * factor),
      padding: padding,
      clipBehavior: clip,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}
