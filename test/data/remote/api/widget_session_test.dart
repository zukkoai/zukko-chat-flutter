import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_upload.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_user.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/zukko_chat_client_service.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/requests/zukko_chat_new_message_request.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/widget_auth_interceptor.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/widget_session.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/widget_session_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fake_chat_server.dart';
import '../../../utils/fixtures.dart';

/// Real Dio + real session + real interceptor against the loopback
/// [FakeChatServer], which applies the server's JWT rules.
void main() {
  late FakeChatServer server;
  late LocalStorage storage;
  late WidgetSession session;
  late Dio dio;
  late ZukkoChatClientServiceImpl service;
  late int resets;
  late List<ZukkoChatException> reported;
  late DateTime clock;

  setUpAll(() async => server = await FakeChatServer.start());
  tearDownAll(() => server.close());

  void rig({ZukkoChatUser? user, LocalStorage? existing}) {
    storage = existing ?? LocalStorage.inMemory();
    resets = 0;
    reported = [];
    clock = DateTime(2026);
    session = WidgetSession(
      api: WidgetSessionApi(
        Dio(BaseOptions(baseUrl: server.baseUrl)),
        FakeChatServer.websiteToken,
      ),
      storage: storage,
      user: user,
      listener: SessionListener(onReset: () => resets++, onError: reported.add),
      now: () => clock,
    );
    dio = Dio(BaseOptions(baseUrl: server.baseUrl));
    dio.interceptors.add(WidgetAuthInterceptor(session: session, dio: dio));
    service = ZukkoChatClientServiceImpl(dio: dio);
  }

  setUp(() {
    server
      ..calls.clear()
      ..reset()
      ..forceStatus = null
      ..hmacMandatory = false
      ..setUserStatus = null
      ..hasConversation = true
      ..pubsubToken = 'pubsub-secret';
  });

  Matcher typed(ZukkoChatExceptionType type) =>
      throwsA(isA<ZukkoChatException>().having((e) => e.type, 'type', type));

  group('start', () {
    test('anonymous: one /config, JWT + pubsub token stored', () async {
      rig();

      await session.start();

      expect(server.requests, ['POST /api/v1/widget/config']);
      expect(server.calls.single.jwt, isEmpty);
      expect(storage.contact.get()!.authToken, 'jwt-1');
      expect(storage.contact.get()!.pubsubToken, 'pubsub-secret');
      expect(session.config!.websiteName, 'Zukko');
      expect(session.config!.raw.containsKey('auth_token'), isFalse);
      expect(resets, 0);
    });

    test('a saved JWT is sent and its contact reused', () async {
      final id = server.addContact();
      rig();
      await storage.contact.save(contact(id: id, authToken: 'jwt-$id'));

      await session.start();

      expect(server.calls.single.jwt, 'jwt-$id');
      expect(server.contacts, hasLength(1));
      expect(storage.contact.get()!.id, id);
    });

    test('identified user: config -> set_user -> config on a token swap, '
        'old conversation dropped', () async {
      final other = server.addContact('someone-else');
      rig(
        user: ZukkoChatUser(
          identifier: 'u1',
          identifierHash: FakeChatServer.hashFor('u1'),
        ),
      );
      await storage.contact.save(contact(id: other, authToken: 'jwt-$other'));
      await storage.conversation.save(conversation());
      await storage.messages.saveMessage(message(1));

      await session.start();

      expect(server.requests, [
        'POST /api/v1/widget/config',
        'PATCH /api/v1/widget/contact/set_user',
        'POST /api/v1/widget/config',
      ]);
      expect(server.calls[1].jwt, 'jwt-$other');
      final newId = storage.contact.get()!.id;
      expect(newId, isNot(other));
      expect(server.calls[2].jwt, 'jwt-$newId');
      expect(storage.contact.get()!.authToken, 'jwt-$newId');
      expect(storage.conversation.get(), isNull);
      expect(storage.messages.getMessages(), isEmpty);
    });

    test('set_user carries identifier, hash and phone_number', () async {
      rig(
        user: ZukkoChatUser(
          identifier: 'u1',
          identifierHash: FakeChatServer.hashFor('u1'),
          name: 'Ali',
          phoneNumber: '+998901234567',
        ),
      );

      await session.start();

      final call = server.to('/contact/set_user').single;
      expect(call.body, {
        'identifier': 'u1',
        'identifier_hash': FakeChatServer.hashFor('u1'),
        'name': 'Ali',
        'phone_number': '+998901234567',
      });
      expect(call.jwt, 'jwt-1');
      expect(call.query['website_token'], FakeChatServer.websiteToken);
    });

    test('set_user keeps the contact: GET /contact confirms it, the stored '
        'identity follows', () async {
      rig(
        user: ZukkoChatUser(
          identifier: 'u1',
          name: 'Ali',
          email: 'a@b.c',
          phoneNumber: '+998901234567',
        ),
      );

      await session.start();

      expect(server.requests, [
        'POST /api/v1/widget/config',
        'PATCH /api/v1/widget/contact/set_user',
        'GET /api/v1/widget/contact',
      ]);
      final stored = storage.contact.get()!;
      expect(stored.contactIdentifier, 'u1');
      expect(stored.name, 'Ali');
      expect(stored.email, 'a@b.c');
      expect(stored.phoneNumber, '+998901234567');
    });

    test('set_user that merged us elsewhere: /config runs once more and the '
        'new contact is adopted', () async {
      server.mergeOnSetUser = true;
      rig(user: ZukkoChatUser(identifier: 'u1'));

      await session.start();

      expect(server.requests, [
        'POST /api/v1/widget/config',
        'PATCH /api/v1/widget/contact/set_user',
        'GET /api/v1/widget/contact',
        'POST /api/v1/widget/config',
      ]);
      expect(storage.contact.get()!.id, 2);
      expect(storage.contact.get()!.authToken, 'jwt-2');
    });

    test('an HMAC 401 fails closed: typed error, no anonymous fallback, '
        'no request goes out', () async {
      rig(
        user: ZukkoChatUser(identifier: 'u1', identifierHash: 'bad'),
      );

      await expectLater(
        session.start(),
        typed(ZukkoChatExceptionType.invalidIdentifierHash),
      );
      expect(session.failure, isNotNull);
      server.calls.clear();

      await expectLater(
        service.getMessages(),
        typed(ZukkoChatExceptionType.invalidIdentifierHash),
      );
      await expectLater(
        session.ensureReady(),
        typed(ZukkoChatExceptionType.invalidIdentifierHash),
      );
      expect(server.calls, isEmpty);
    });

    test('another set_user failure of an identified user is retryable and '
        'never anonymous', () async {
      server.setUserStatus = 500;
      rig(user: ZukkoChatUser(identifier: 'u1'));

      await expectLater(
        session.start(),
        typed(ZukkoChatExceptionType.identifyFailed),
      );

      expect(session.isReady, isFalse);
      expect(session.failure, isNull); // not terminal
      server.calls.clear();
      await expectLater(
        service.getMessages(),
        typed(ZukkoChatExceptionType.identifyFailed),
      );
      expect(server.requests, isEmpty);
    });

    test('a set_user failure without an identifier is only reported', () async {
      server.setUserStatus = 500;
      rig(user: ZukkoChatUser(name: 'Jane'));

      await session.start();

      expect(reported.single.type, ZukkoChatExceptionType.identifyFailed);
      expect(await service.getMessages(), isNotEmpty);
    });

    test('a failed /config is typed and can be retried', () async {
      server.forceStatus = 500;
      rig();

      await expectLater(
        session.start(),
        typed(ZukkoChatExceptionType.getConfigFailed),
      );

      server.forceStatus = null;
      clock = clock.add(const Duration(seconds: 5)); // past the start backoff
      await session.start();
      expect(storage.contact.get(), isNotNull);
    });

    test('a request before start() starts the session itself', () async {
      rig();

      await service.getMessages();

      expect(server.requests.first, 'POST /api/v1/widget/config');
    });
  });

  group('requests', () {
    test('carry website_token and X-Auth-Token', () async {
      rig();
      await session.start();
      server.calls.clear();

      await service.getMessages(after: 3);

      final call = server.calls.single;
      expect(call.query, {
        'after': '3',
        'website_token': FakeChatServer.websiteToken,
      });
      expect(call.jwt, 'jwt-1');
    });

    test('401 and 410 become SESSION_EXPIRED, without recovery', () async {
      rig();
      await session.start();
      server.calls.clear();
      server.forceStatus = 410;

      await expectLater(
        service.getMessages(),
        typed(ZukkoChatExceptionType.sessionExpired),
      );
      expect(server.requests, ['GET /api/v1/widget/messages']);
    });
  });

  group('404 recovery', () {
    test('a stale JWT: revalidate via /config, adopt the new contact, replay '
        'once with the NEW headers', () async {
      rig();
      await session.start();
      await storage.conversation.save(conversation());
      server.calls.clear();
      server.forgetContacts(); // our JWT is stale now

      final messages = await service.getMessages();

      expect(messages, isNotEmpty);
      expect(server.requests, [
        'GET /api/v1/widget/messages',
        'POST /api/v1/widget/config',
        'GET /api/v1/widget/messages',
      ]);
      expect(server.calls[0].jwt, 'jwt-1');
      expect(server.calls[1].jwt, 'jwt-1'); // revalidates with the current JWT
      final fresh = storage.contact.get()!;
      expect(fresh.id, isNot(1));
      expect(server.calls[2].jwt, 'jwt-${fresh.id}');
      expect(
        server.calls[2].query['website_token'],
        FakeChatServer.websiteToken,
      );
      expect(storage.conversation.get(), isNull);
      expect(resets, 1);
    });

    test(
      'a 404 with a valid JWT passes through: no reset, no replay',
      () async {
        rig();
        await session.start();
        await storage.conversation.save(conversation());
        server.calls.clear();

        await expectLater(
          dio.get<dynamic>('/api/v1/widget/conversations/toggle_status'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'status',
              404,
            ),
          ),
        );

        expect(server.requests, [
          'GET /api/v1/widget/conversations/toggle_status',
          'POST /api/v1/widget/config',
        ]);
        expect(storage.contact.get()!.id, 1);
        expect(storage.conversation.get(), isNotNull);
        expect(resets, 0);
        expect(session.generation, 0);
      },
    );

    test('toggle_typing 404 (no conversation) never calls /config', () async {
      server.hasConversation = false;
      rig();
      await session.start();
      server.calls.clear();

      await expectLater(service.toggleTyping(true), throwsA(anything));
      await expectLater(service.updateLastSeen(), completes);

      expect(server.requests, [
        'POST /api/v1/widget/conversations/toggle_typing',
        'POST /api/v1/widget/conversations/update_last_seen',
      ]);
    });

    test(
      'a noRecover request with a stale JWT is not repaired either',
      () async {
        rig();
        await session.start();
        server.calls.clear();
        server.forgetContacts();

        await expectLater(service.toggleTyping(true), throwsA(anything));

        expect(server.requests, hasLength(1));
      },
    );

    test('concurrent 404s coalesce into one session rebuild', () async {
      rig();
      await session.start();
      server.calls.clear();
      server.forgetContacts();

      final results = await Future.wait([
        service.getMessages(),
        service.getMessages(),
        service.getMessages(),
      ]);

      expect(results.every((r) => r.isNotEmpty), isTrue);
      expect(server.to('/config'), hasLength(1));
      expect(server.to('/messages'), hasLength(6)); // 3 failed + 3 replayed
      expect(resets, 1);
      expect(server.contacts, hasLength(1));
    });

    test('rate limit: 3 rebuilds per minute, then SESSION_EXPIRED; allowed '
        'again after the window', () async {
      rig();
      await session.start();

      for (var i = 0; i < WidgetSession.maxRefreshes; i++) {
        server.forgetContacts();
        await service.getMessages();
      }
      server.forgetContacts();
      server.calls.clear();

      await expectLater(
        service.getMessages(),
        typed(ZukkoChatExceptionType.sessionExpired),
      );
      expect(server.requests, ['GET /api/v1/widget/messages']); // no loop

      clock = clock.add(const Duration(seconds: 61));
      expect(await service.getMessages(), isNotEmpty);
    });

    test('a multipart body is replayed as a clone', () async {
      rig();
      await session.start();
      server.calls.clear();
      server.forgetContacts();

      final created = await service.createMessage(
        ZukkoChatNewMessageRequest(content: '', echoId: 'e'),
        attachments: [
          ZukkoChatUpload.bytes(
            name: 'a.txt',
            bytes: Uint8List.fromList('FILE-BYTES'.codeUnits),
          ),
        ],
      );

      expect(created.id, 100);
      final posts = server.to('/messages');
      expect(posts, hasLength(2));
      for (final post in posts) {
        expect(post.body, contains('FILE-BYTES'));
        expect(post.body, contains('message[attachments][]'));
      }
      expect(posts.last.jwt, isNot(posts.first.jwt));
    });
  });

  group('secrets', () {
    test('the JWT is not in toJson, toString or the log output', () async {
      final logs = <String>[];
      final originalPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = originalPrint);
      rig(
        user: ZukkoChatUser(
          identifier: 'u1',
          identifierHash: FakeChatServer.hashFor('u1'),
        ),
      );

      await session.start();
      server.forgetContacts();
      await service.getMessages(); // a recovery
      server.hasConversation = false;
      await service.toggleTyping(true).onError((_, _) {}); // a failure

      final stored = storage.contact.get()!;
      expect(stored.authToken, startsWith('jwt-'));
      expect(stored.toJson().toString(), isNot(contains('jwt-')));
      expect(stored.toJson().containsKey('auth_token'), isFalse);
      expect(stored.toString(), isNot(contains('jwt-')));
      final output = logs.join('\n');
      expect(output, isNot(contains('jwt-')));
      expect(output, isNot(contains(FakeChatServer.hashFor('u1'))));
      expect(output, isNot(contains('pubsub-secret')));
      expect(output, isNot(contains(FakeChatServer.websiteToken)));
    });
  });
}
