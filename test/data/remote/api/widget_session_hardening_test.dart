import 'dart:async';
import 'dart:io';

import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_upload.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_user.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_upload_policy.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/widget_session.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/widget_session_api.dart';
import 'package:zukko_chat_flutter/src/shared/http_client.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fixtures.dart';
import '../../../utils/scripted_widget.dart';

typedef T = ZukkoChatExceptionType;

Matcher typed(T type) =>
    throwsA(isA<ZukkoChatException>().having((e) => e.type, 'type', type));

/// Never answers: a server that accepts the connection and goes silent.
class _HangingAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    return Completer<ResponseBody>().future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ScriptedWidget server;
  final identified = ZukkoChatUser(identifier: 'u1', identifierHash: 'h');

  setUp(() => server = ScriptedWidget());

  group('set_user fails closed for an identified user (8)', () {
    for (final status in [500, 404, 422, 503]) {
      test('HTTP $status: IDENTIFY_FAILED, not ready, no REST send', () async {
        server.setUserStatus = status;
        final rig = WidgetRig(server, user: identified);

        await expectLater(rig.session.start(), typed(T.identifyFailed));

        expect(rig.session.isReady, isFalse);
        expect(rig.session.failure, isNull); // retryable, not terminal
        server.http.requests.clear();
        await expectLater(rig.service.getMessages(), typed(T.identifyFailed));
        await expectLater(
          rig.service.createMessage(rig.sendRequest),
          typed(T.identifyFailed),
        );
        expect(server.count('/messages'), 0);
      });
    }

    test('a 401 stays terminal INVALID_IDENTIFIER_HASH', () async {
      server.setUserStatus = 401;
      final rig = WidgetRig(server, user: identified);

      await expectLater(rig.session.start(), typed(T.invalidIdentifierHash));
      rig.advance(const Duration(minutes: 5));

      expect(rig.session.failure?.type, T.invalidIdentifierHash);
      await expectLater(rig.session.start(), typed(T.invalidIdentifierHash));
      expect(server.count('/set_user'), 1);
    });

    test('a later start can succeed (retry allowed)', () async {
      server.setUserStatus = 500;
      final rig = WidgetRig(server, user: identified);
      await expectLater(rig.session.start(), typed(T.identifyFailed));

      server.setUserStatus = 200;
      rig.advance(const Duration(seconds: 10));
      await rig.session.start();

      expect(rig.session.isReady, isTrue);
    });

    test('a failing GET /contact check is IDENTIFY_FAILED too', () async {
      server.contactStatus = 500;
      final rig = WidgetRig(server, user: identified);

      await expectLater(rig.session.start(), typed(T.identifyFailed));

      expect(rig.session.isReady, isFalse);
    });

    test('a user without identifier still carries on anonymously', () async {
      server.setUserStatus = 500;
      final rig = WidgetRig(server, user: ZukkoChatUser(name: 'Jane'));

      await rig.session.start();

      expect(rig.session.isReady, isTrue);
      expect(rig.reported.single.type, T.identifyFailed);
    });
  });

  group('start is rate limited (9)', () {
    test(
      'failures back off: no /config storm, the last error is rethrown',
      () async {
        server.configStatus = 500;
        final rig = WidgetRig(server);

        for (var i = 0; i < 20; i++) {
          await expectLater(rig.session.start(), typed(T.getConfigFailed));
        }
        expect(server.count('/config'), 1);

        rig.advance(const Duration(seconds: 3)); // 2 s pause elapsed
        await expectLater(rig.session.start(), typed(T.getConfigFailed));
        expect(server.count('/config'), 2);

        rig.advance(const Duration(seconds: 3)); // the pause doubled to 4 s
        await expectLater(rig.session.start(), typed(T.getConfigFailed));
        expect(server.count('/config'), 2);
        rig.advance(const Duration(seconds: 2));
        await expectLater(rig.session.start(), typed(T.getConfigFailed));
        expect(server.count('/config'), 3);
      },
    );

    test('requests through the interceptor do not storm either', () async {
      server.configStatus = 500;
      final rig = WidgetRig(server);

      for (var i = 0; i < 10; i++) {
        await expectLater(rig.service.getMessages(), typed(T.getConfigFailed));
      }

      expect(server.count('/config'), 1);
    });

    test('a never answering server does not hold the session lock', () {
      fakeAsync((async) {
        final hang = _HangingAdapter();
        final start = DateTime(2026);
        final session = WidgetSession(
          api: WidgetSessionApi(
            Dio(BaseOptions(baseUrl: 'https://chat.test'))
              ..httpClientAdapter = hang,
            'site',
          ),
          storage: WidgetRig(server).storage,
          now: () => start.add(async.elapsed),
        );
        Object? first;
        session.start().catchError((Object e) => first = e);

        async.elapse(WidgetSession.stepTimeout + const Duration(seconds: 1));
        expect(
          first,
          isA<ZukkoChatException>().having(
            (e) => e.type,
            'type',
            T.getConfigFailed,
          ),
        );

        // the lock is free again: the next start (after the pause) runs
        async.elapse(const Duration(seconds: 5));
        Object? second;
        session.start().catchError((Object e) => second = e);
        async.elapse(const Duration(seconds: 1));
        expect(hang.calls, 2);
        async.elapse(WidgetSession.stepTimeout);
        expect(second, isA<ZukkoChatException>());
      });
    });
  });

  group('half-failed rebuild (6)', () {
    test(
      'contact replaced, then the 2nd /config fails: still a reset',
      () async {
        final rig = WidgetRig(server, user: identified);
        await rig.storage.contact.save(contact(id: 5, authToken: 'jwt-5'));
        server.configContacts.add(9); // /config with the stale JWT: new contact
        server.setUserBody = {'id': 9, 'widget_auth_token': 'NEW'};
        final generation = rig.session.generation;
        // the 2nd /config (after set_user) fails
        var configs = 0;
        final original = server.http.handler;
        server.http.handler = (o) =>
            o.path.endsWith('/config') && ++configs == 2
            ? (500, {'error': 'x'})
            : original(o);

        await expectLater(rig.session.start(), typed(T.getConfigFailed));

        expect(rig.storage.contact.get()!.id, 9);
        expect(rig.resets, 1);
        expect(rig.session.generation, generation + 1);
        expect(rig.session.isReady, isFalse);
      },
    );

    test('widget_auth_token goes to the 2nd /config and is stored only after '
        'it succeeded', () async {
      final rig = WidgetRig(server, user: identified);
      server.setUserBody = {'id': 2, 'widget_auth_token': 'NEW'};
      server.configContacts.addAll([1, 2]);

      await rig.session.start();

      final configs = [
        for (var i = 0; i < server.http.requests.length; i++)
          if (server.http.requests[i].path.endsWith('/config')) server.jwts[i],
      ];
      expect(configs, [null, 'NEW']);
      expect(rig.storage.contact.get()!.id, 2);
      expect(rig.storage.contact.get()!.authToken, 'jwt-2');
    });

    test('a failing 2nd /config never stores the widget_auth_token', () async {
      final rig = WidgetRig(server, user: identified);
      server.setUserBody = {'id': 2, 'widget_auth_token': 'NEW'};
      var configs = 0;
      final original = server.http.handler;
      server.http.handler = (o) => o.path.endsWith('/config') && ++configs == 2
          ? (500, {'error': 'x'})
          : original(o);

      await expectLater(rig.session.start(), typed(T.getConfigFailed));

      expect(rig.storage.contact.get()!.authToken, isNot('NEW'));
    });
  });

  group('404 recovery budget (15)', () {
    test(
      'genuine 404s that find the SAME contact do not use the budget',
      () async {
        final rig = WidgetRig(server);
        await rig.session.start();
        server.messagesStatus = 404;

        for (var i = 0; i < 8; i++) {
          await expectLater(
            rig.service.getMessages(),
            throwsA(isA<ZukkoChatException>()),
          );
        }

        expect(server.count('/config'), 1 + 8); // one probe each
        // a real rebuild is still possible afterwards
        server.contactId = 2;
        server.messagesStatus = 200;
        expect(
          await rig.session.refresh(SessionRefreshReason.socketRejected),
          isTrue,
        );
      },
    );

    test('a bad website_token ends in a typed error and cannot loop', () async {
      final rig = WidgetRig(server);
      await rig.session.start();
      server.configStatus = 404; // unknown website_token
      server.messagesStatus = 404;

      for (var i = 0; i < 6; i++) {
        await expectLater(
          rig.service.getMessages(),
          throwsA(
            isA<ZukkoChatException>().having(
              (e) => e.type,
              'type',
              anyOf(T.getConfigFailed, T.sessionExpired),
            ),
          ),
        );
      }

      // 1 initial + at most maxRefreshes probes, then SESSION_EXPIRED
      expect(server.count('/config'), 1 + WidgetSession.maxRefreshes);
    });
  });

  // B6: one owner announces "the session was replaced"
  group('reset bookkeeping (B6)', () {
    test('a rebuild that changes nothing is not a reset', () async {
      final rig = WidgetRig(server);
      await rig.session.start();
      final generation = rig.session.generation;

      final changed = await rig.session.refresh(
        SessionRefreshReason.socketRejected,
      );

      expect(changed, isFalse);
      expect(rig.resets, 0);
      expect(rig.session.generation, generation);
    });

    test('same contact, new pubsub token: exactly one reset', () async {
      final rig = WidgetRig(server);
      await rig.session.start();
      final generation = rig.session.generation;
      server.pubsub = 'pub-2';

      final changed = await rig.session.refresh(
        SessionRefreshReason.socketRejected,
      );

      expect(changed, isTrue);
      expect(rig.resets, 1);
      expect(rig.session.generation, generation + 1);
    });

    test('another contact: exactly one reset, however it was found', () async {
      final rig = WidgetRig(server);
      await rig.session.start();
      server.contactId = 2;

      await rig.session.refresh(SessionRefreshReason.staleToken);

      expect(rig.resets, 1);
    });

    test('a first start is never a reset', () async {
      final rig = WidgetRig(server);

      await rig.session.start();

      expect(rig.resets, 0);
      expect(rig.session.generation, 0);
    });
  });

  group('identity logging (10)', () {
    late List<String> logs;
    late DebugPrintCallback saved;
    setUp(() {
      logs = [];
      saved = debugPrint;
      debugPrint = (m, {wrapWidth}) => logs.add(m ?? '');
    });
    tearDown(() => debugPrint = saved);

    test(
      'identifier without hash, inbox not enforcing: silent, no onError',
      () async {
        final rig = WidgetRig(server, user: ZukkoChatUser(identifier: 'u1'));

        await rig.session.start();
        await rig.session.refresh(SessionRefreshReason.socketRejected);

        expect(rig.session.isReady, isTrue);
        expect(rig.reported, isEmpty);
        expect(logs, isEmpty);
      },
    );

    test('401 without a hash: one ERROR line, "missing"', () async {
      server.setUserStatus = 401;
      final rig = WidgetRig(server, user: ZukkoChatUser(identifier: 'u1'));

      await expectLater(
        rig.session.start(),
        throwsA(
          isA<ZukkoChatException>().having(
            (e) => e.type,
            'type',
            T.invalidIdentifierHash,
          ),
        ),
      );

      expect(logs, hasLength(1));
      expect(logs.single, startsWith('[zukko_chat] ERROR: '));
      expect(logs.single, contains('identifierHash is missing'));
    });

    test('401 with a hash: one ERROR line, "wrong"', () async {
      server.setUserStatus = 401;
      final rig = WidgetRig(server, user: identified);

      await expectLater(
        rig.session.start(),
        throwsA(isA<ZukkoChatException>()),
      );

      expect(logs, hasLength(1));
      expect(logs.single, contains('identifierHash is wrong'));
      expect(logs.single, isNot(contains("'h'")));
    });

    test('with a hash there is no warning', () async {
      final rig = WidgetRig(server, user: identified);
      await rig.session.start();
      expect(rig.reported, isEmpty);
    });
  });

  group('Dio hardening (7)', () {
    late HttpServer origin;
    late HttpServer other;
    var otherHits = 0;
    var originHits = 0;
    var seenAuth = <String?>[];

    setUp(() async {
      otherHits = originHits = 0;
      seenAuth = [];
      other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      other.listen((r) {
        otherHits++;
        seenAuth.add(r.headers.value('X-Auth-Token'));
        r.response
          ..write('{}')
          ..close();
      });
      origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      origin.listen((r) {
        originHits++;
        r.response
          ..statusCode = 302
          ..headers.set('location', 'http://127.0.0.1:${other.port}/x')
          ..close();
      });
    });

    tearDown(() async {
      await origin.close(force: true);
      await other.close(force: true);
    });

    test(
      'a 302 to another host is not followed: typed error, one request',
      () async {
        final dio = zukkoChatDio('http://127.0.0.1:${origin.port}');

        await expectLater(
          dio.get<Object?>(
            '/x',
            options: Options(headers: {'X-Auth-Token': 'secret'}),
          ),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'status',
              302,
            ),
          ),
        );

        expect(originHits, 1);
        expect(otherHits, 0);
        expect(seenAuth, isEmpty);
      },
    );

    test(
      'the session turns a redirecting /config into GET_CONFIG_FAILED',
      () async {
        final session = WidgetSession(
          api: WidgetSessionApi(
            zukkoChatDio('http://127.0.0.1:${origin.port}'),
            'site',
          ),
          storage: WidgetRig(server).storage,
        );

        await expectLater(session.start(), typed(T.getConfigFailed));

        expect(otherHits, 0);
      },
    );

    test('timeouts are set', () {
      final o = zukkoChatDio('https://x.test').options;
      expect(o.followRedirects, isFalse);
      expect(o.connectTimeout, const Duration(seconds: 15));
      expect(o.receiveTimeout, const Duration(seconds: 30));
      expect(o.sendTimeout, const Duration(seconds: 60));
    });
  });

  group('uploads (11)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('upload_'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<ZukkoChatUpload> sparse(int bytes) async {
      final f = File('${dir.path}/big.png');
      final raf = await f.open(mode: FileMode.write);
      await raf.truncate(bytes); // sparse: no real 40 MB written
      await raf.close();
      return ZukkoChatUpload.file(
        name: 'big.png',
        path: f.path,
      ); // size unknown
    }

    test('a path upload of unknown size over 40 MB is rejected', () async {
      final big = await sparse(ZukkoChatUpload.maxSize + 1);

      await expectLater(validateUpload(big), typed(T.sendMessageFailed));
    });

    test('exactly 40 MB passes', () async {
      final ok = await sparse(ZukkoChatUpload.maxSize);

      await validateUpload(ok);
    });

    test('the service rejects it before building the form', () async {
      final big = await sparse(ZukkoChatUpload.maxSize + 1);
      final rig = WidgetRig(server);

      await expectLater(
        rig.service.createMessage(rig.sendRequest, attachments: [big]),
        typed(T.sendMessageFailed),
      );
      expect(server.count('/messages'), 0);
    });
  });

  test('ZukkoChatUser.toString carries no identity data (13)', () {
    final u = ZukkoChatUser(
      identifier: 'id-secret',
      identifierHash: 'hash-secret',
      email: 'a@b.c',
      name: 'Name',
      customAttributes: {'k': 'attr-secret'},
    );

    final text = '$u';

    for (final secret in ['id-secret', 'hash-secret', 'a@b.c', 'attr-secret']) {
      expect(text, isNot(contains(secret)));
    }
  });
}
