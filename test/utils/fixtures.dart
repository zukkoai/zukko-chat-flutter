import 'package:zukko_chat_flutter/src/data/models/zukko_chat_contact.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_conversation.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_message.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_user.dart';

ZukkoChatContact contact({
  int id = 1,
  String? identifier = 'source-1',
  String? pubsubToken = 'token-1',
  String? authToken,
}) => ZukkoChatContact(
  id: id,
  contactIdentifier: identifier,
  pubsubToken: pubsubToken,
  name: 'name $id',
  email: 'c$id@test.com',
  authToken: authToken,
);

ZukkoChatConversation conversation({int id = 7}) =>
    ZukkoChatConversation(id: id, inboxId: 1, status: 'open');

/// [createdAt] must be lexicographically sortable (the model stores a string).
ZukkoChatMessage message(
  int id, {
  String? createdAt,
  String content = 'hello',
  int messageType = 0,
}) => ZukkoChatMessage(
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

ZukkoChatUser user({String? identifier = 'user-1', String? name = 'User'}) =>
    ZukkoChatUser(identifier: identifier, name: name);
