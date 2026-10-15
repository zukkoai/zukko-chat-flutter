import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:zukko_chat_flutter/src/core/chatwoot_client_exception.dart';
import 'package:zukko_chat_flutter/src/core/chatwoot_upload.dart';
import 'package:zukko_chat_flutter/src/data/models/chatwoot_conversation.dart';
import 'package:zukko_chat_flutter/src/data/models/chatwoot_message.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/chatwoot_client_service.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/requests/chatwoot_new_message_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Scriptable [ChatwootClientService]: set the `*Result`s, inspect the records.
class FakeClientService extends Fake implements ChatwootClientService {
  Object? conversationResult; // ZukkoChatConversation?, or an exception
  Object? messagesResult = <ZukkoChatMessage>[];
  Object? createMessageResult; // ZukkoChatMessage or an exception

  final createdMessageRequests = <ChatwootNewMessageRequest>[];
  final uploadedAttachments = <List<ZukkoChatUpload>>[];
  final typing = <bool>[];
  var getMessagesCalls = 0;
  var updateLastSeenCalls = 0;

  /// `(before, after)` of every [getMessages] call.
  final messageCursors = <({int? before, int? after})>[];

  /// When set, [getMessages] answers these pages in order (instead of
  /// [messagesResult]).
  List<List<ZukkoChatMessage>>? messagePages;

  T _unwrap<T>(Object? result) {
    if (result is Exception || result is Error) throw result as Object;
    return result as T;
  }

  @override
  Future<ZukkoChatConversation?> getConversation() async =>
      _unwrap(conversationResult);

  @override
  Future<List<ZukkoChatMessage>> getMessages({int? before, int? after}) async {
    getMessagesCalls++;
    messageCursors.add((before: before, after: after));
    final pages = messagePages;
    if (pages != null) return pages.isEmpty ? [] : pages.removeAt(0);
    return _unwrap(messagesResult);
  }

  @override
  Future<ZukkoChatMessage> createMessage(
    ChatwootNewMessageRequest request, {
    List<ZukkoChatUpload> attachments = const [],
  }) async {
    createdMessageRequests.add(request);
    uploadedAttachments.add(attachments);
    return _unwrap(createMessageResult);
  }

  @override
  Future<void> toggleTyping(bool on) async {
    typing.add(on);
    if (typingResult != null) throw typingResult!;
  }

  Object? typingResult;

  @override
  Future<void> updateLastSeen() async {
    updateLastSeenCalls++;
  }
}

/// A scripted websocket peer: [emit] frames as the server, inspect what the
/// client [sent], close it from either side.
class FakeChannel extends Fake implements WebSocketChannel {
  final _incoming = StreamController<dynamic>();
  final FakeSink _sink = FakeSink();

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future.value();

  /// Decoded frames the client wrote.
  List<Map<String, dynamic>> get sent => [
    for (final f in _sink.added)
      jsonDecode(f as String) as Map<String, dynamic>,
  ];

  /// Decoded `update_presence` frames among [sent].
  int get presenceFrames => sent
      .where(
        (f) =>
            f['command'] == 'message' &&
            jsonDecode(f['data'] as String)['action'] == 'update_presence',
      )
      .length;

  bool get isClosedByClient => _sink.closeCode != null;
  int? get closeCodeByClient => _sink.closeCode;
  set failOnAdd(bool value) => _sink.failOnAdd = value;

  /// A JSON object/list is encoded, a String is sent as is, anything else raw.
  void emit(Object frame) =>
      _incoming.add(frame is Map || frame is List ? jsonEncode(frame) : frame);

  void welcome() => emit({'type': 'welcome'});
  void confirm() => emit({'type': 'confirm_subscription'});
  void ping() => emit({'type': 'ping', 'message': 1});

  /// ActionCable broadcast: `{identifier, message: {event, data}}`.
  void event(String name, Map<String, Object?> data) => emit({
    'identifier': '{"channel":"RoomChannel"}',
    'message': {'event': name, 'data': data},
  });

  void serverClose() => _incoming.close();
  void serverError() => _incoming.addError(const SocketException('lost'));
}

class FakeSink extends Fake implements WebSocketSink {
  final added = <Object?>[];
  int? closeCode;
  bool failOnAdd = false;

  @override
  void add(Object? data) {
    if (failOnAdd || closeCode != null) throw StateError('sink is closed');
    added.add(data);
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    this.closeCode ??= closeCode ?? 1005;
  }
}

/// Channel factory handed to `ChatwootSocket`: records urls, hands out
/// [FakeChannel]s.
class FakeSocketHub {
  final urls = <Uri>[];
  final channels = <FakeChannel>[];
  Object? failWith;

  FakeChannel get last => channels.last;

  WebSocketChannel connect(Uri url) {
    urls.add(url);
    if (failWith != null) throw failWith!;
    final channel = FakeChannel();
    channels.add(channel);
    return channel;
  }
}

ZukkoChatException failure(ZukkoChatExceptionType type) =>
    ZukkoChatException('boom', type);
