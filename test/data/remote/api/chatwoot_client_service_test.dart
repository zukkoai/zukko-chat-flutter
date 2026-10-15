import 'dart:typed_data';

import 'package:chatwoot_sdk/src/core/chatwoot_client_exception.dart';
import 'package:chatwoot_sdk/src/core/chatwoot_upload.dart';
import 'package:chatwoot_sdk/src/data/local/local_storage.dart';
import 'package:chatwoot_sdk/src/data/remote/api/chatwoot_client_api_interceptor.dart';
import 'package:chatwoot_sdk/src/data/remote/api/chatwoot_client_auth_service.dart';
import 'package:chatwoot_sdk/src/data/remote/api/chatwoot_client_service.dart';
import 'package:chatwoot_sdk/src/data/remote/api/requests/chatwoot_new_message_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fake_http.dart';
import '../../../utils/fixtures.dart';
import '../../../utils/test_resources_util.dart';

const _conv = '/public/api/v1/inboxes/inbox/contacts/source-1/conversations';

void main() {
  late FakeHttpAdapter http;
  late ChatwootClientServiceImpl service;

  setUp(() async {
    // contact + conversation 7 already stored, so no auth calls are involved
    final storage = LocalStorage.inMemory();
    await storage.contact.save(contact());
    await storage.conversation.save(conversation(id: 7));
    http = FakeHttpAdapter((_) => (200, {}));
    final dio = dioWith(http)
      ..interceptors.add(
        ChatwootClientApiInterceptor(
          'inbox',
          storage,
          ChatwootClientAuthServiceImpl(
            dio: dioWith(FakeHttpAdapter((_) => (500, {}))),
          ),
        ),
      );
    service = ChatwootClientServiceImpl(dio: dio);
  });

  group('REST', () {
    test('createMessage', () async {
      http.handler = (_) => (200, message(8).toJson());

      final created = await service.createMessage(
        ChatwootNewMessageRequest(content: 'hi', echoId: 'e1'),
      );

      expect(created.id, 8);
      expect(http.calls, ['POST $_conv/7/messages']);
      expect(http.requests.single.data, {'content': 'hi', 'echo_id': 'e1'});
    });

    test('createMessageWithAttachments sends multipart', () async {
      http.handler = (_) => (200, message(9).toJson());

      final created = await service.createMessageWithAttachments(
        ChatwootNewMessageRequest(content: '', echoId: 'e2'),
        [
          ChatwootUpload.bytes(
            name: 'photo.png',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );

      expect(created.id, 9);
      expect(http.calls, ['POST $_conv/7/messages']);
      final form = http.requests.single.data as FormData;
      expect(form.fields.map((f) => '${f.key}=${f.value}'), ['echo_id=e2']);
      final part = form.files.single;
      expect(part.key, 'attachments[]');
      expect(part.value.filename, 'photo.png');
      expect(part.value.contentType?.mimeType, 'image/png');
    });

    test('getAllMessages', () async {
      final json = await TestResourceUtil.readJsonResource(
        fileName: 'messages',
      );
      http.handler = (_) => (200, json);

      final messages = await service.getAllMessages();

      expect(messages, isNotEmpty);
      expect(http.calls, ['GET $_conv/7/messages']);
    });

    test('getContact', () async {
      http.handler = (_) => (200, contact().toJson());

      expect(await service.getContact(), contact());
      expect(http.calls, [
        'GET /public/api/v1/inboxes/inbox/contacts/source-1',
      ]);
    });

    test('getConversations', () async {
      http.handler = (_) => (200, [conversation(id: 3).toJson()]);

      final conversations = await service.getConversations();

      expect(conversations.single.id, 3);
      expect(http.calls, ['GET $_conv']);
    });

    // SEC6
    test('getAllMessages skips a poisoned item and ids <= 0', () async {
      http.handler = (_) => (
        200,
        [
          message(1).toJson(),
          {'id': 2, 'content': 12345}, // wrong type
          'not even an object',
          {'content': 'no id'},
          {...message(5).toJson(), 'id': -3},
          {...message(4).toJson(), 'created_at': 1e300},
          message(3).toJson(),
        ],
      );

      final messages = await service.getAllMessages();

      expect(messages.map((m) => m.id), [1, 4, 3]);
    });

    test('getConversations: one broken conversation or message does not '
        'block the rest', () async {
      http.handler = (_) => (
        200,
        [
          {
            ...conversation(id: 3).toJson(),
            'messages': [
              message(1).toJson(),
              {'id': 'x', 'content': 9},
            ],
          },
          {'id': 'garbage'},
        ],
      );

      final conversations = await service.getConversations();

      expect(conversations.map((c) => c.id), [3]);
      expect(conversations.single.messages.map((m) => m.id), [1]);
    });

    // SEC9
    test('a hostile source_id stays one encoded path segment', () async {
      final storage = LocalStorage.inMemory();
      await storage.contact.save(contact(sourceId: 'a/../b?x=1#y'));
      await storage.conversation.save(conversation(id: 7));
      final adapter = FakeHttpAdapter((_) => (200, contact().toJson()));
      final hostile = ChatwootClientServiceImpl(
        dio: dioWith(adapter)
          ..interceptors.add(
            ChatwootClientApiInterceptor(
              'in/box',
              storage,
              ChatwootClientAuthServiceImpl(dio: dioWith(adapter)),
            ),
          ),
      );

      await hostile.getContact();

      expect(
        adapter.requests.single.path,
        '/public/api/v1/inboxes/in%2Fbox/contacts/a%2F..%2Fb%3Fx%3D1%23y',
      );
    });

    for (final bad in ['', '.', '..', 'x' * 257]) {
      test('source_id "${bad.length > 5 ? 'x * ${bad.length}' : bad}" is '
          'rejected with a typed error and no request', () async {
        final storage = LocalStorage.inMemory();
        await storage.contact.save(contact(sourceId: bad));
        final adapter = FakeHttpAdapter((_) => (200, {}));
        final rejecting = ChatwootClientServiceImpl(
          dio: dioWith(adapter)
            ..interceptors.add(
              ChatwootClientApiInterceptor(
                'in',
                storage,
                ChatwootClientAuthServiceImpl(dio: dioWith(adapter)),
              ),
            ),
        );

        await expectLater(
          rejecting.getContact(),
          throwsA(isA<ChatwootClientException>()),
        );
        expect(adapter.requests, isEmpty);
      });
    }
  });

  group('failures map to the call-specific typed exception', () {
    final calls =
        <
          String,
          (
            ChatwootClientExceptionType,
            Future<void> Function(ChatwootClientService),
          )
        >{
          'createMessage': (
            ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
            (s) => s.createMessage(
              ChatwootNewMessageRequest(content: 'a', echoId: 'b'),
            ),
          ),
          'getAllMessages': (
            ChatwootClientExceptionType.GET_MESSAGES_FAILED,
            (s) => s.getAllMessages(),
          ),
          'getContact': (
            ChatwootClientExceptionType.GET_CONTACT_FAILED,
            (s) => s.getContact(),
          ),
          'getConversations': (
            ChatwootClientExceptionType.GET_CONVERSATION_FAILED,
            (s) => s.getConversations(),
          ),
        };

    for (final entry in calls.entries) {
      final (type, call) = entry.value;

      test('${entry.key}: HTTP 500', () async {
        http.handler = (_) => (500, {'error': 'server'});

        await expectLater(
          call(service),
          throwsA(
            isA<ChatwootClientException>().having((e) => e.type, 'type', type),
          ),
        );
      });

      test('${entry.key}: malformed body', () async {
        http.handler = (_) => (200, 'garbage');

        await expectLater(
          call(service),
          throwsA(
            isA<ChatwootClientException>().having((e) => e.type, 'type', type),
          ),
        );
      });
    }
  });
}
