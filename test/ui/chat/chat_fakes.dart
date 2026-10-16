import 'dart:async';

import 'package:zukko_chat_flutter/src/data/models/zukko_chat_attachment.dart';
import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClient extends Fake implements ZukkoChatClient {
  bool disposed = false;
  int loads = 0;
  Object? sendError;
  final sent =
      <({String content, String echoId, List<ZukkoChatUpload> attachments})>[];

  int seen = 0;
  final typing = <bool>[];

  /// When set, [loadMessages] completes only after it (the real one answers
  /// through the callbacks first).
  Completer<void>? loadGate;

  @override
  Future<void> loadMessages() async {
    loads++;
    await loadGate?.future;
  }

  @override
  Future<void> markSeen() async => seen++;

  /// `before` of every [loadOlderMessages] call; [older] answers it.
  final olderRequests = <int>[];
  Future<List<ZukkoChatMessage>?> Function(int before) older = (_) async => [];

  @override
  Future<List<ZukkoChatMessage>?> loadOlderMessages({required int before}) {
    olderRequests.add(before);
    return older(before);
  }

  int resumes = 0;

  @override
  void resume() => resumes++;

  @override
  Future<void> setTyping(bool on) async => typing.add(on);

  @override
  Future<void> sendMessage({
    required String content,
    required String echoId,
    List<ZukkoChatUpload> attachments = const [],
    int? replyTo,
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
  late Completer<ZukkoChatClient> completer = Completer<ZukkoChatClient>();
  ZukkoChatCallbacks? callbacks;
  bool? allowInsecure;
  int calls = 0;

  Future<ZukkoChatClient> call({
    required String baseUrl,
    required String websiteToken,
    ZukkoChatUser? user,
    bool enablePersistence = true,
    bool allowInsecure = false,
    ZukkoChatCallbacks? callbacks,
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

ZukkoChatMessage msg(
  int id, {
  String? content = 'hello',
  int? type = 1,
  String? createdAt,
  List<dynamic>? attachments,
  ZukkoChatEventMessageUser? sender,
}) => ZukkoChatMessage(
  id: id,
  content: content,
  messageType: type,
  contentType: 'text',
  contentAttributes: null,
  createdAt:
      createdAt ??
      '2024-01-01 10:${(id ~/ 60).toString().padLeft(2, '0')}:${(id % 60).toString().padLeft(2, '0')}',
  conversationId: 7,
  attachments: attachmentsFromJson(attachments),
  sender: sender,
);
