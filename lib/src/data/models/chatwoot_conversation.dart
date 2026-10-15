import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../shared/json_converters.dart';
import '../local/hive_type_ids.dart';
import 'chatwoot_contact.dart';
import 'chatwoot_message.dart';

part 'chatwoot_conversation.g.dart';

@JsonSerializable(explicitToJson: true)
@HiveType(typeId: chatwootConversationHiveTypeId)
class ChatwootConversation extends Equatable {
  ///The numeric ID of the conversation
  @JsonKey(fromJson: idFromJson)
  @HiveField(0)
  final int id;

  ///The numeric ID of the inbox
  @JsonKey(name: "inbox_id", fromJson: idFromJson)
  @HiveField(1)
  final int inboxId;

  ///List of all messages from the conversation
  @JsonKey(fromJson: _messagesFromJson)
  @HiveField(2)
  final List<ChatwootMessage> messages;

  ///Contact of the conversation (absent in `GET /conversations`)
  @JsonKey()
  @HiveField(3)
  final ChatwootContact? contact;

  ///Conversation status (`open`, `resolved`, `pending`, `snoozed`)
  @JsonKey()
  @HiveField(4)
  final String? status;

  const ChatwootConversation({
    required this.id,
    required this.inboxId,
    this.messages = const [],
    this.contact,
    this.status,
  });

  factory ChatwootConversation.fromJson(Map<String, dynamic> json) =>
      _$ChatwootConversationFromJson(json);

  Map<String, dynamic> toJson() => _$ChatwootConversationToJson(this);

  @override
  List<Object?> get props => [id, inboxId, messages, contact, status];
}

List<ChatwootMessage> _messagesFromJson(Object? data) =>
    data == null ? const [] : parseMessages(data);
