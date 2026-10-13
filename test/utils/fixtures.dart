import 'package:chatwoot_sdk/src/data/models/chatwoot_contact.dart';
import 'package:chatwoot_sdk/src/data/models/chatwoot_conversation.dart';
import 'package:chatwoot_sdk/src/data/models/chatwoot_message.dart';
import 'package:chatwoot_sdk/src/data/models/chatwoot_user.dart';

ChatwootContact contact({
  int id = 1,
  String? sourceId = 'source-1',
  String? pubsubToken = 'token-1',
}) => ChatwootContact(
  id: id,
  contactIdentifier: sourceId,
  pubsubToken: pubsubToken,
  name: 'name $id',
  email: 'c$id@test.com',
);

ChatwootConversation conversation({int id = 7, ChatwootContact? forContact}) =>
    ChatwootConversation(
      id: id,
      inboxId: 1,
      messages: const [],
      contact: forContact ?? contact(),
    );

/// [createdAt] must be lexicographically sortable (the model stores a string).
ChatwootMessage message(
  int id, {
  String? createdAt,
  String content = 'hello',
  int messageType = 0,
}) => ChatwootMessage(
  id: id,
  content: content,
  messageType: messageType,
  contentType: 'text',
  contentAttributes: null,
  createdAt: createdAt ?? '2024-01-01 10:00:0$id',
  conversationId: 7,
  attachments: null,
  sender: null,
);

ChatwootUser user({String? identifier = 'user-1', String? name = 'User'}) =>
    ChatwootUser(identifier: identifier, name: name);
