import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../shared/json_converters.dart';
import '../local/hive_type_ids.dart';

part 'zukko_chat_conversation.g.dart';

/// The contact's conversation with the agents, as far as the app needs it: its
/// ids and its [status]. Messages are delivered separately
/// (`ZukkoChatCallbacks.onMessagesRetrieved`, `onMessageReceived`, ...).
///
/// The app receives it through `ZukkoChatCallbacks.onConversationUpdated`.
///
/// Hive fields 2 and 3 (an old message list and contact) are retired: never
/// reuse those indices.
///
/// {@category FlutterClientSdk}
@JsonSerializable(explicitToJson: true)
@HiveType(typeId: zukkoChatConversationHiveTypeId)
class ZukkoChatConversation extends Equatable {
  /// `status` value of a conversation an agent has resolved.
  static const statusResolved = 'resolved';

  /// The numeric ID of the conversation.
  @JsonKey(fromJson: idFromJson)
  @HiveField(0)
  final int id;

  /// The numeric ID of the inbox the conversation belongs to.
  @JsonKey(name: "inbox_id", fromJson: idFromJson)
  @HiveField(1)
  final int inboxId;

  /// Conversation status: `open`, `resolved`, `pending` or `snoozed`; null when
  /// the server did not say. The contact can keep writing after `resolved`.
  @HiveField(4)
  final String? status;

  const ZukkoChatConversation({
    required this.id,
    required this.inboxId,
    this.status,
  });

  /// An agent resolved this conversation.
  bool get isResolved => status == statusResolved;

  /// A copy with the given (non-null) fields replaced.
  ZukkoChatConversation copyWith({int? inboxId, String? status}) =>
      ZukkoChatConversation(
        id: id,
        inboxId: inboxId ?? this.inboxId,
        status: status ?? this.status,
      );

  factory ZukkoChatConversation.fromJson(Map<String, dynamic> json) =>
      _$ZukkoChatConversationFromJson(json);

  Map<String, dynamic> toJson() => _$ZukkoChatConversationToJson(this);

  @override
  List<Object?> get props => [id, inboxId, status];
}
