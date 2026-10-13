import 'package:json_annotation/json_annotation.dart';

import '../../models/chatwoot_event_message_user.dart';
import '../../models/chatwoot_message.dart';

part 'chatwoot_event.g.dart';

@JsonSerializable(explicitToJson: true)
class ChatwootEventMessage {
  @JsonKey()
  final ChatwootEventMessageData? data;

  @JsonKey(toJson: eventMessageTypeToJson, fromJson: eventMessageTypeFromJson)
  final ChatwootEventMessageType? event;

  ChatwootEventMessage({this.data, this.event});

  factory ChatwootEventMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatwootEventMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ChatwootEventMessageToJson(this);
}

@JsonSerializable(explicitToJson: true)
/// The subset of a `message.*` / typing / presence / conversation event payload
/// the SDK reads; [getMessage] re-parses the message fields into a
/// [ChatwootMessage].
class ChatwootEventMessageData {
  @JsonKey()
  final String? content;

  @JsonKey(name: "content_attributes")
  final dynamic contentAttributes;

  @JsonKey(name: "content_type")
  final String? contentType;

  @JsonKey(name: "conversation_id")
  final int? conversationId;

  @JsonKey(name: "created_at")
  final dynamic createdAt;

  @JsonKey(name: "echo_id")
  final String? echoId;

  @JsonKey()
  final int? id;

  @JsonKey(name: "message_type")
  final int? messageType;

  @JsonKey(name: "private")
  final bool? private;

  /// Set on typing events: a typing indicator of a private note.
  @JsonKey(name: "is_private")
  final bool? isPrivate;

  @JsonKey()
  final ChatwootEventMessageUser? sender;

  @JsonKey()
  final String? status;

  @JsonKey()
  final dynamic users;

  ChatwootEventMessageData({
    this.id,
    this.echoId,
    this.sender,
    this.conversationId,
    this.createdAt,
    this.contentAttributes,
    this.contentType,
    this.messageType,
    this.content,
    this.status,
    this.private,
    this.isPrivate,
    this.users,
  });

  factory ChatwootEventMessageData.fromJson(Map<String, dynamic> json) =>
      _$ChatwootEventMessageDataFromJson(json);

  Map<String, dynamic> toJson() => _$ChatwootEventMessageDataToJson(this);

  ChatwootMessage getMessage() => ChatwootMessage.fromJson(toJson());
}

/// Server events a contact receives, with their wire names.
enum ChatwootEventMessageType {
  presence_update('presence.update'),
  message_created('message.created'),
  message_updated('message.updated'),
  conversation_typing_off('conversation.typing_off'),
  conversation_typing_on('conversation.typing_on'),
  conversation_status_changed('conversation.status_changed');

  const ChatwootEventMessageType(this.wire);

  final String wire;

  /// `null` for events this SDK does not know.
  static ChatwootEventMessageType? byWire(Object? value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}

String? eventMessageTypeToJson(ChatwootEventMessageType? type) => type?.wire;

ChatwootEventMessageType? eventMessageTypeFromJson(Object? value) =>
    ChatwootEventMessageType.byWire(value);
