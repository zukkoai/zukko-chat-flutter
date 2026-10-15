import 'package:flutter_chat_core/flutter_chat_core.dart';

/// Time and delivery state of one message, as the styles show them.
class MessageMeta {
  final String time;

  /// Last message of a group (or not grouped): the one that shows the time.
  final bool isGroupEnd;

  /// First message of a group (or not grouped): the one that shows the author.
  final bool isGroupStart;
  final MessageStatus? status;

  const MessageMeta({
    required this.time,
    required this.isGroupEnd,
    required this.isGroupStart,
    required this.status,
  });

  factory MessageMeta.of(
    Message message,
    DateFormat format,
    MessageGroupStatus? group,
  ) {
    final at = message.resolvedTime;
    return MessageMeta(
      time: at == null ? '' : format.format(at.toLocal()),
      isGroupEnd: group == null || group.isLast,
      isGroupStart: group == null || group.isFirst,
      status: message.resolvedStatus,
    );
  }

  bool get failed => status == MessageStatus.error;
  bool get sending => status == MessageStatus.sending;
}
