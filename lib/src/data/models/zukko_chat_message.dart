import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../shared/json_converters.dart';
import '../local/hive_type_ids.dart';
import 'zukko_chat_attachment.dart';
import 'zukko_chat_event_message_user.dart';

part 'zukko_chat_message.g.dart';

/// Stored in Hive (type id [zukkoChatMessageHiveTypeId], fields 0-8 in
/// declaration order) by the hand-written [ZukkoChatMessageAdapter]; field 7
/// holds plain JSON maps.
///
/// {@category FlutterClientSdk}
@JsonSerializable(explicitToJson: true)
class ZukkoChatMessage extends Equatable {
  ///unique identifier of the message
  @JsonKey(fromJson: idFromJson)
  final int id;

  ///text content of the message
  final String? content;

  ///type of message: 0 incoming (sent by the contact), 1 outgoing (agent),
  ///2 activity, 3 template
  @JsonKey(name: "message_type", fromJson: intFromJson)
  final int? messageType;

  ///content type of message
  @JsonKey(name: "content_type")
  final String? contentType;

  @JsonKey(name: "content_attributes", fromJson: jsonMapFromJson)
  final Map<String, dynamic>? contentAttributes;

  ///date and time message was created
  @JsonKey(name: "created_at", fromJson: createdAtFromJson)
  final String createdAt;

  ///id of the conversation the message belongs to
  @JsonKey(name: "conversation_id", fromJson: intFromJson)
  final int? conversationId;

  ///list of media/doc/file attachment for message
  @JsonKey(fromJson: attachmentsFromJson)
  final List<ZukkoChatAttachment>? attachments;

  ///The user this message belongs to
  @JsonKey(name: "sender")
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

/// Hive adapter of [ZukkoChatMessage]. Hand-written so attachments stay plain
/// JSON maps (no extra type id) and old records (`List<dynamic>` of maps) load.
class ZukkoChatMessageAdapter extends TypeAdapter<ZukkoChatMessage> {
  @override
  final typeId = zukkoChatMessageHiveTypeId;

  @override
  ZukkoChatMessage read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{
      for (var i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return ZukkoChatMessage(
      id: (f[0] as num).toInt(),
      content: f[1] as String?,
      messageType: (f[2] as num?)?.toInt(),
      contentType: f[3] as String?,
      contentAttributes: jsonMapFromJson(f[4]),
      createdAt: f[5] as String,
      conversationId: (f[6] as num?)?.toInt(),
      attachments: attachmentsFromJson(f[7]),
      sender: f[8] as ZukkoChatEventMessageUser?,
    );
  }

  @override
  void write(BinaryWriter writer, ZukkoChatMessage obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.messageType)
      ..writeByte(3)
      ..write(obj.contentType)
      ..writeByte(4)
      ..write(obj.contentAttributes)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.conversationId)
      ..writeByte(7)
      ..write(obj.attachments?.map((a) => a.toJson()).toList())
      ..writeByte(8)
      ..write(obj.sender);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      other is ZukkoChatMessageAdapter && other.typeId == typeId;
}
