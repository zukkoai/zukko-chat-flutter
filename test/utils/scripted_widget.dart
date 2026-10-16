import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_user.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/zukko_chat_client_service.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/requests/zukko_chat_new_message_request.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/widget_auth_interceptor.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/widget_session.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/widget_session_api.dart';
import 'package:dio/dio.dart';

import 'fake_http.dart';

/// A scripted widget server on a [FakeHttpAdapter]: set the knobs, read
/// [FakeHttpAdapter.calls]. Every `/config` answers contact [contactId] and
/// pubsub token [pubsub] with a JWT derived from the contact id.
class ScriptedWidget {
  ScriptedWidget() {
    http = FakeHttpAdapter(_handle);
  }

  late final FakeHttpAdapter http;
  int configStatus = 200;
  int setUserStatus = 200;
  int contactStatus = 200;
  int messagesStatus = 200;
  int contactId = 1;
  String pubsub = 'pub-1';
  Object? setUserBody = const {'id': 1};

  /// Contact id the next `/config` calls answer, in order (then [contactId]).
  final configContacts = <int>[];
  int sentId = 42;
  List<Map<String, Object?>> messages = [];

  /// Headers of every request, in order.
  final jwts = <String?>[];

  int count(String suffix) =>
      http.requests.where((r) => r.path.endsWith(suffix)).length;

  Map<String, Object?> messageJson(int id) => {
    'id': id,
    'content': 'm$id',
    'message_type': 1,
    'content_type': 'text',
    'created_at': 1700000000 + id,
    'conversation_id': 7,
  };

  (int, Object?) _handle(RequestOptions o) {
    jwts.add(o.headers['X-Auth-Token'] as String?);
    final p = o.path;
    if (p.endsWith('/config')) {
      if (configStatus != 200) return (configStatus, {'error': 'x'});
      final id = configContacts.isEmpty
          ? contactId
          : configContacts.removeAt(0);
      return (
        200,
        {
          'website_channel_config': {'auth_token': 'jwt-$id'},
          'contact': {
            'id': id,
            'identifier': null,
            'name': 'n',
            'pubsub_token': pubsub,
          },
          'global_config': <String, Object?>{},
        },
      );
    }
    if (p.endsWith('/contact/set_user')) return (setUserStatus, setUserBody);
    if (p.endsWith('/contact')) return (contactStatus, {'id': contactId});
    if (p.endsWith('/conversations')) {
      return (200, {'id': 7, 'inbox_id': 1, 'status': 'open'});
    }
    if (p.endsWith('/messages')) {
      if (messagesStatus != 200) return (messagesStatus, {'error': 'x'});
      if (o.method == 'GET') {
        return (200, {'payload': messages, 'meta': <String, Object?>{}});
      }
      return (200, messageJson(sentId));
    }
    return (200, <String, Object?>{});
  }
}

/// Session + interceptor + service on one [ScriptedWidget].
class WidgetRig {
  WidgetRig(
    this.server, {
    ZukkoChatUser? user,
    LocalStorage? storage,
    void Function()? onReset,
    void Function()? onReady,
    void Function(ZukkoChatException)? onError,
    DateTime Function()? now,
  }) : storage = storage ?? LocalStorage.inMemory() {
    session = WidgetSession(
      api: WidgetSessionApi(dioWith(server.http), 'site'),
      storage: this.storage,
      user: user,
      listener: SessionListener(
        onReset: () {
          resets++;
          onReset?.call();
        },
        onReady: onReady,
        onError: (e) {
          reported.add(e);
          onError?.call(e);
        },
      ),
      now: now ?? () => clock,
    );
    dio = dioWith(server.http);
    dio.interceptors.add(WidgetAuthInterceptor(session: session, dio: dio));
    service = ZukkoChatClientServiceImpl(dio: dio);
  }

  final ScriptedWidget server;
  final LocalStorage storage;
  late final WidgetSession session;
  late final Dio dio;
  late final ZukkoChatClientService service;
  DateTime clock = DateTime(2026);
  int resets = 0;
  final reported = <ZukkoChatException>[];

  final sendRequest = ZukkoChatNewMessageRequest(content: 'hi', echoId: 'e1');

  void advance(Duration d) => clock = clock.add(d);
}
