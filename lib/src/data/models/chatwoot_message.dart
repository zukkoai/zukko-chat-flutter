import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../shared/json_converters.dart';
import '../local/hive_type_ids.dart';
import 'chatwoot_event_message_user.dart';

part 'chatwoot_message.g.dart';

/// {@category FlutterClientSdk}
@JsonSerializable(explicitToJson: true)
@HiveType(typeId: chatwootMessageHiveTypeId)
class ChatwootMessage extends Equatable {
  ///unique identifier of the message
  @JsonKey(fromJson: idFromJson)
  @HiveField(0)
  final int id;

  ///text content of the message
  @JsonKey()
  @HiveField(1)
  final String? content;

  ///type of message: 0 incoming (sent by the contact), 1 outgoing (agent),
  ///2 activity, 3 template
  @JsonKey(name: "message_type", fromJson: intFromJson)
  @HiveField(2)
  final int? messageType;

  ///content type of message
  @JsonKey(name: "content_type")
  @HiveField(3)
  final String? contentType;

  @JsonKey(name: "content_attributes")
  @HiveField(4)
  final dynamic contentAttributes;

  ///date and time message was created
  @JsonKey(name: "created_at", fromJson: createdAtFromJson)
  @HiveField(5)
  final String createdAt;

  ///id of the conversation the message belongs to
  @JsonKey(name: "conversation_id", fromJson: intFromJson)
  @HiveField(6)
  final int? conversationId;

  ///list of media/doc/file attachment for message
  @JsonKey()
  @HiveField(7)
  final List<dynamic>? attachments;

  ///The user this message belongs to
  @JsonKey(name: "sender")
  @HiveField(8)
  final ChatwootEventMessageUser? sender;

  ///checks if message was sent by the contact making the request
  bool get isMine => messageType == 0;

  const ChatwootMessage({
    required this.id,
    required this.content,
    required this.messageType,
    required this.contentType,
    required this.contentAttributes,
    required this.createdAt,
    required this.conversationId,
    required this.attachments,
    required this.sender,
  });

  factory ChatwootMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatwootMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ChatwootMessageToJson(this);

  @override
  List<Object?> get props => [
    id,
    content,
    messageType,
    contentType,
    contentAttributes,
    createdAt,
    conversationId,
    attachments,
    sender,
  ];
}

/// Parses a JSON list of messages, skipping malformed items and items without
/// a positive id (a missing id would collide with every other id-less message).
List<ChatwootMessage> parseMessages(Object? data) => [
  for (final m in parseList(data, ChatwootMessage.fromJson))
    if (m.id > 0) m,
];

/// Parses the body of `GET /messages`: `{payload: [...], meta: {...}}` (a bare
/// list is accepted too). Malformed items are skipped like in [parseMessages].
List<ChatwootMessage> parseMessagesPage(Object? data) =>
    parseMessages(data is Map<String, dynamic> ? data['payload'] : data);
