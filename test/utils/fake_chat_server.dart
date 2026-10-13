import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'fixtures.dart';

/// A tiny real HTTP server speaking the (legacy) Chatwoot public client API.
/// The contact has no pubsub token so clients never open a websocket.
class FakeChatServer {
  FakeChatServer._(this._server) {
    _server.listen(_handle);
  }

  final HttpServer _server;

  /// `METHOD path` of every request received.
  final requests = <String>[];

  /// Answer every request with this status instead (e.g. 500).
  int? forceStatus;

  static Future<FakeChatServer> start() async =>
      FakeChatServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  int count(String method, bool Function(String path) where) => requests
      .where(
        (r) =>
            r.startsWith('$method ') && where(r.substring(method.length + 1)),
      )
      .length;

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add('${request.method} $path');
    await request.drain<void>();

    Object body;
    var status = forceStatus ?? 200;
    final contactJson = contact(pubsubToken: null).toJson();
    if (path.endsWith('/messages')) {
      body = request.method == 'POST'
          ? message(100).toJson()
          : [message(1).toJson(), message(2).toJson()];
    } else if (path.endsWith('/conversations')) {
      final conversationJson = conversation(id: 7).toJson();
      body = request.method == 'POST' ? conversationJson : [conversationJson];
    } else {
      body = contactJson;
    }

    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }
}
