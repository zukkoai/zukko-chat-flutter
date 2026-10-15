import 'dart:async';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClient extends Fake implements ChatwootClient {
  bool disposed = false;
  int loads = 0;
  Object? sendError;
  final sent =
      <({String content, String echoId, List<ChatwootUpload> attachments})>[];

  @override
  Future<void> loadMessages() async => loads++;

  @override
  Future<void> sendMessage({
    required String content,
    required String echoId,
    List<ChatwootUpload> attachments = const [],
  }) async {
    if (sendError != null) throw sendError!;
    sent.add((content: content, echoId: echoId, attachments: attachments));
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// A client factory the test completes by hand.
class FakeFactory {
  // late: created inside the test body, i.e. in the test's zone (a Completer
  // made in setUp does not deliver errors to listeners of the fake-async zone)
  late Completer<ChatwootClient> completer = Completer<ChatwootClient>();
  ChatwootCallbacks? callbacks;
  bool? allowInsecure;
  int calls = 0;

  Future<ChatwootClient> call({
    required String baseUrl,
    required String inboxIdentifier,
    ChatwootUser? user,
    bool enablePersistence = true,
    bool allowInsecure = false,
    ChatwootCallbacks? callbacks,
  }) {
    calls++;
    this.allowInsecure = allowInsecure;
    this.callbacks = callbacks;
    return completer.future;
  }
}

class SpyChat extends InMemoryChatController {
  int sets = 0;
  int inserts = 0;

  @override
  Future<void> setMessages(List<Message> messages, {bool animated = true}) {
    sets++;
    return super.setMessages(messages, animated: animated);
  }

  @override
  Future<void> insertMessage(
    Message message, {
    int? index,
    bool animated = true,
  }) {
    inserts++;
    return super.insertMessage(message, index: index, animated: animated);
  }
}

ChatwootMessage msg(
  int id, {
  String? content = 'hello',
  int? type = 1,
  String? createdAt,
  List<dynamic>? attachments,
  ChatwootEventMessageUser? sender,
}) => ChatwootMessage(
  id: id,
  content: content,
  messageType: type,
  contentType: 'text',
  contentAttributes: null,
  createdAt:
      createdAt ??
      '2024-01-01 10:${(id ~/ 60).toString().padLeft(2, '0')}:${(id % 60).toString().padLeft(2, '0')}',
  conversationId: 7,
  attachments: attachments,
  sender: sender,
);
