import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import '../local/hive_type_ids.dart';
import 'chatwoot_contact.dart';
import 'chatwoot_message.dart';

part 'chatwoot_conversation.g.dart';

@JsonSerializable(explicitToJson: true)
@HiveType(typeId: chatwootConversationHiveTypeId)
class ChatwootConversation extends Equatable {
  ///The numeric ID of the conversation
  @JsonKey()
  @HiveField(0)
  final int id;

  ///The numeric ID of the inbox
  @JsonKey(name: "inbox_id")
  @HiveField(1)
  final int inboxId;

  ///List of all messages from the conversation
  @JsonKey(fromJson: _messagesFromJson)
  @HiveField(2)
  final List<ChatwootMessage> messages;

  ///Contact of the conversation
  @JsonKey()
  @HiveField(3)
  final ChatwootContact contact;

  const ChatwootConversation({
    required this.id,
    required this.inboxId,
    required this.messages,
    required this.contact,
  });

  factory ChatwootConversation.fromJson(Map<String, dynamic> json) =>
      _$ChatwootConversationFromJson(json);

  Map<String, dynamic> toJson() => _$ChatwootConversationToJson(this);

  @override
  List<Object?> get props => [id, inboxId, messages, contact];
}

List<ChatwootMessage> _messagesFromJson(Object? data) =>
    data == null ? const [] : parseMessages(data);
