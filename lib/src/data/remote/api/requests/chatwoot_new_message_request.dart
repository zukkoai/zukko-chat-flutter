import 'package:equatable/equatable.dart';

/// What the app wants to send: the text, its temporary id and the message it
/// replies to. The wire format is built by `buildMessageJson` / `buildMessageForm`.
class ChatwootNewMessageRequest extends Equatable {
  final String content;
  final String echoId;

  /// Id of the message this one replies to.
  final int? replyTo;

  const ChatwootNewMessageRequest({
    required this.content,
    required this.echoId,
    this.replyTo,
  });

  @override
  List<Object?> get props => [content, echoId, replyTo];
}
