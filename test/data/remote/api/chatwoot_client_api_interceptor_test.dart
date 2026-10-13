import 'package:chatwoot_sdk/src/core/chatwoot_client_exception.dart';
import 'package:chatwoot_sdk/src/data/local/local_storage.dart';
import 'package:chatwoot_sdk/src/data/remote/api/chatwoot_client_api_interceptor.dart';
import 'package:chatwoot_sdk/src/data/remote/api/chatwoot_client_auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fake_http.dart';
import '../../../utils/fixtures.dart';

const _template =
    '/public/api/v1/inboxes/${ChatwootClientApiInterceptor.inboxPlaceholder}'
    '/contacts/${ChatwootClientApiInterceptor.contactPlaceholder}'
    '/conversations/${ChatwootClientApiInterceptor.conversationPlaceholder}/messages';

/// Real Dio + real interceptor + real auth service + in-memory storage; only
/// the network is faked.
void main() {
  late LocalStorage storage;
  late FakeHttpAdapter api; // authenticated requests
  late FakeHttpAdapter auth; // contact / conversation creation
  late Dio dio;

  Object? contactJson = contact().toJson();

  setUp(() {
    contactJson = contact().toJson();
    storage = LocalStorage.inMemory();
    auth = FakeHttpAdapter(
      (o) => o.path.endsWith('/conversations')
          ? (200, conversation(id: 42).toJson())
          : (200, contactJson),
    );
    api = FakeHttpAdapter((_) => (200, []));
    dio = dioWith(api)
      ..interceptors.add(
        ChatwootClientApiInterceptor(
          'inbox',
          storage,
          ChatwootClientAuthServiceImpl(dio: dioWith(auth)),
        ),
      );
  });

  test('without a contact: creates contact and conversation, then resolves '
      'every placeholder', () async {
    await storage.user.save(user());

    await dio.get<dynamic>(_template);

    expect(auth.calls, [
      'POST /public/api/v1/inboxes/inbox/contacts',
      'POST /public/api/v1/inboxes/inbox/contacts/source-1/conversations',
    ]);
    expect(auth.requests.first.data, user().toJson());
    expect(storage.contact.get(), contact());
    expect(storage.conversation.get()!.id, 42);
    expect(api.calls, [
      'GET /public/api/v1/inboxes/inbox/contacts/source-1/conversations/42/messages',
    ]);
  });

  test('with a stored contact but no conversation: only creates the '
      'conversation', () async {
    await storage.contact.save(contact());

    await dio.get<dynamic>(_template);

    expect(auth.calls, [
      'POST /public/api/v1/inboxes/inbox/contacts/source-1/conversations',
    ]);
    expect(storage.conversation.get()!.id, 42);
  });

  test('with contact and conversation stored: no auth calls', () async {
    await storage.contact.save(contact());
    await storage.conversation.save(conversation(id: 5));

    await dio.get<dynamic>(_template);

    expect(auth.requests, isEmpty);
    expect(api.calls.single, contains('/conversations/5/messages'));
  });

  test('parallel first requests create the contact only once', () async {
    await Future.wait([dio.get<dynamic>(_template), dio.get<dynamic>(_template)]);

    expect(auth.calls.where((c) => c.endsWith('/contacts')), hasLength(1));
    expect(api.requests, hasLength(2));
  });

  // P11: used to be `contactIdentifier!`
  test('a contact without source_id fails with a typed error, no request is '
      'sent', () async {
    contactJson = contact(sourceId: null).toJson();

    await expectLater(
      dio.get<dynamic>(_template),
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'error',
          isA<ChatwootClientException>().having(
            (e) => e.type,
            'type',
            ChatwootClientExceptionType.CREATE_CONTACT_FAILED,
          ),
        ),
      ),
    );
    expect(api.requests, isEmpty);
  });

  test(
    'a failed contact creation rejects the request with the cause',
    () async {
      auth.handler = (_) => (500, {});

      await expectLater(dio.get<dynamic>(_template), throwsA(isA<DioException>()));
      expect(api.requests, isEmpty);
      expect(storage.contact.get(), isNull);
    },
  );

  // S9 / S10: Dio delivers 4xx to onError - onResponse never saw them
  group('session recovery on 401 / 403 / 404', () {
    setUp(() async {
      await storage.contact.save(contact());
      await storage.conversation.save(conversation(id: 5));
      await storage.messages.saveMessage(message(1));
      // fresh session the auth service will hand out
      contactJson = contact(id: 2, sourceId: 'source-2').toJson();
    });

    int count(FakeHttpAdapter a, String call) =>
        a.calls.where((c) => c == call).length;

    void scriptAuth() {
      auth.handler = (o) => o.path.endsWith('/conversations')
          ? (200, conversation(id: 42).toJson())
          : o.method == 'POST'
          ? (200, contactJson)
          : (200, {'payload': 'replayed'});
    }

    for (final status in [401, 403]) {
      test('$status: new contact + conversation, one replay, request '
          'succeeds', () async {
        api.handler = (_) => (status, {'error': 'gone'});
        scriptAuth();

        final response = await dio.get<dynamic>(_template);

        expect(response.data, {'payload': 'replayed'});
        expect(api.calls, hasLength(1)); // the rejected attempt
        expect(auth.calls, [
          'POST /public/api/v1/inboxes/inbox/contacts',
          'POST /public/api/v1/inboxes/inbox/contacts/source-2/conversations',
          'GET /public/api/v1/inboxes/inbox/contacts/source-2/conversations/42/messages',
        ]);
        expect(storage.contact.get()!.contactIdentifier, 'source-2');
        expect(storage.conversation.get()!.id, 42);
        expect(storage.messages.getMessages(), isEmpty); // old session's data
      });
    }

    // F12
    test('404 on the messages path resets only the conversation: the contact '
        'and its source_id are kept', () async {
      api.handler = (_) => (404, {'error': 'gone'});
      scriptAuth();

      final response = await dio.get<dynamic>(_template);

      expect(response.data, {'payload': 'replayed'});
      expect(auth.calls, [
        'POST /public/api/v1/inboxes/inbox/contacts/source-1/conversations',
        'GET /public/api/v1/inboxes/inbox/contacts/source-1/conversations/42/messages',
      ]);
      expect(storage.contact.get(), contact());
      expect(storage.conversation.get()!.id, 42);
      expect(storage.messages.getMessages(), isEmpty);
    });

    test('404 on the contact path resets the contact too', () async {
      api.handler = (_) => (404, {});
      scriptAuth();
      auth.handler = (o) => o.path.endsWith('/conversations')
          ? (200, conversation(id: 42).toJson())
          : o.method == 'POST'
          ? (200, contactJson)
          : (200, {'ok': true});

      await dio.get<dynamic>(
        '/public/api/v1/inboxes/${ChatwootClientApiInterceptor.inboxPlaceholder}'
        '/contacts/${ChatwootClientApiInterceptor.contactPlaceholder}',
      );

      expect(storage.contact.get()!.contactIdentifier, 'source-2');
    });

    test('a 404 on the conversations list path resets the contact too', () async {
      api.handler = (_) => (404, {});
      scriptAuth();

      await dio.get<dynamic>(
        '/public/api/v1/inboxes/${ChatwootClientApiInterceptor.inboxPlaceholder}'
        '/contacts/${ChatwootClientApiInterceptor.contactPlaceholder}/conversations',
      );

      expect(storage.contact.get()!.contactIdentifier, 'source-2');
    });

    // SEC8
    test('resets are rate limited: the 4th reset within a minute is passed '
        'through and keeps the stored session', () async {
      var now = DateTime(2026);
      final limited = Dio(BaseOptions(baseUrl: 'https://chat.test'))
        ..httpClientAdapter = api
        ..interceptors.add(
          ChatwootClientApiInterceptor(
            'inbox',
            storage,
            ChatwootClientAuthServiceImpl(dio: dioWith(auth)),
            now: () => now,
          ),
        );
      api.handler = (_) => (404, {});
      scriptAuth();

      for (var i = 0; i < ChatwootClientApiInterceptor.maxResets; i++) {
        await limited.get<dynamic>(_template);
        now = now.add(const Duration(seconds: 1));
      }
      final before = storage.conversation.get();
      await expectLater(limited.get<dynamic>(_template), throwsA(isA<DioException>()));
      expect(storage.conversation.get(), before);

      now = now.add(ChatwootClientApiInterceptor.resetWindow);
      await limited.get<dynamic>(_template); // window passed: recovery works again
    });

    test('onSessionReset fires once per reset, after the new session is '
        'stored', () async {
      var resets = 0;
      String? tokenSeen;
      final watched = Dio(BaseOptions(baseUrl: 'https://chat.test'))
        ..httpClientAdapter = api
        ..interceptors.add(
          ChatwootClientApiInterceptor(
            'inbox',
            storage,
            ChatwootClientAuthServiceImpl(dio: dioWith(auth)),
            onSessionReset: () {
              resets++;
              tokenSeen = storage.contact.get()?.pubsubToken;
            },
          ),
        );
      contactJson = contact(
        id: 2,
        sourceId: 'source-2',
        pubsubToken: 'token-B',
      ).toJson();
      api.handler = (_) => (401, {});
      scriptAuth();

      await Future.wait([watched.get<dynamic>(_template), watched.get<dynamic>(_template)]);

      expect(resets, 1);
      expect(tokenSeen, 'token-B');
    });

    test(
      'the user survives the reset and is sent to the new contact',
      () async {
        await storage.user.save(user());
        api.handler = (_) => (401, {});
        auth.handler = (o) => o.path.endsWith('/conversations')
            ? (200, conversation(id: 42).toJson())
            : (200, contactJson);

        await dio.get<dynamic>(_template);

        expect(auth.requests.first.data, user().toJson());
        expect(storage.user.get(), user());
      },
    );

    test('concurrent failures create the session once', () async {
      api.handler = (_) => (401, {});
      auth.handler = (o) => o.path.endsWith('/conversations')
          ? (200, conversation(id: 42).toJson())
          : (200, o.method == 'POST' ? contactJson : []);

      final responses = await Future.wait([
        for (var i = 0; i < 4; i++) dio.get<dynamic>(_template),
      ]);

      expect(responses.map((r) => r.statusCode), everyElement(200));
      expect(count(auth, 'POST /public/api/v1/inboxes/inbox/contacts'), 1);
      expect(
        count(
          auth,
          'POST /public/api/v1/inboxes/inbox/contacts/source-2/conversations',
        ),
        1,
      );
      // every request was replayed on the new session, once each
      expect(
        auth.calls.where(
          (c) =>
              c.startsWith('GET ') && c.contains('source-2/conversations/42'),
        ),
        hasLength(4),
      );
    });

    test('a second 401 rejects - no loop, no second session', () async {
      api.handler = (_) => (401, {});
      auth.handler = (o) => o.path.endsWith('/conversations')
          ? (200, conversation(id: 42).toJson())
          : o.method == 'POST'
          ? (200, contactJson)
          : (401, {});

      await expectLater(
        dio.get<dynamic>(_template),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );

      expect(count(auth, 'POST /public/api/v1/inboxes/inbox/contacts'), 1);
      expect(api.calls, hasLength(1));
    });

    test('a failing session recreation rejects with the typed cause', () async {
      api.handler = (_) => (401, {});
      auth.handler = (_) => (500, {});

      await expectLater(
        dio.get<dynamic>(_template),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<ChatwootClientException>().having(
              (e) => e.type,
              'type',
              ChatwootClientExceptionType.CREATE_CONTACT_FAILED,
            ),
          ),
        ),
      );
    });

    test('other statuses are passed through untouched', () async {
      api.handler = (_) => (500, {});

      await expectLater(
        dio.get<dynamic>(_template),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            500,
          ),
        ),
      );

      expect(auth.requests, isEmpty);
      expect(storage.contact.get()!.contactIdentifier, 'source-1');
    });
  });
}
