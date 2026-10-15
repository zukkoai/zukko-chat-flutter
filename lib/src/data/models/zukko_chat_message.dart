import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../shared/json_converters.dart';
import '../local/hive_type_ids.dart';
import 'zukko_chat_event_message_user.dart';

part 'zukko_chat_message.g.dart';

/// {@category FlutterClientSdk}
@JsonSerializable(explicitToJson: true)
@HiveType(typeId: zukkoChatMessageHiveTypeId)
class ZukkoChatMessage extends Equatable {
  ///unique identifier of the message
  @JsonKey(fromJson: idFromJson)
  @HiveField(0)
  final int id;

  ///text content of the message
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
  @HiveField(7)
  final List<dynamic>? attachments;

  ///The user this message belongs to
  @JsonKey(name: "sender")
  @HiveField(8)
  final ZukkoChatEventMessageUser? sender;

  /// `messageType` of a message the contact sent.
  static const typeFromContact = 0;

  /// `messageType` of an agent's reply.
  static const typeFromAgent = 1;

  /// `messageType` of a system activity line (assignment, status change).
  static const typeActivity = 2;

  /// `messageType` of a template message.
  static const typeTemplate = 3;

  ///checks if message was sent by the contact making the request
  bool get isMine => messageType == typeFromContact;

  /// A system activity line, not part of the conversation text.
  bool get isActivity => messageType == typeActivity;

  /// A template message.
  bool get isTemplate => messageType == typeTemplate;

  const ZukkoChatMessage({
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

  factory ZukkoChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ZukkoChatMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ZukkoChatMessageToJson(this);

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
List<ZukkoChatMessage> parseMessages(Object? data) => [
  for (final m in parseList(data, ZukkoChatMessage.fromJson))
    if (m.id > 0) m,
];
