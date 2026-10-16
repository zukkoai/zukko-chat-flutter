import 'dart:typed_data';

import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_upload.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/zukko_chat_client_service.dart';
import 'package:zukko_chat_flutter/src/data/remote/api/requests/zukko_chat_new_message_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fake_http.dart';
import '../../../utils/fixtures.dart';
import '../../../utils/test_resources_util.dart';

const _widget = '/api/v1/widget';

/// The service on a plain Dio: auth headers are the interceptor's business.
void main() {
  late FakeHttpAdapter http;
  late ZukkoChatClientServiceImpl service;

  setUp(() {
    http = FakeHttpAdapter((_) => (200, {}));
    service = ZukkoChatClientServiceImpl(dio: dioWith(http));
  });

  group('REST', () {
    test('createMessage sends the JSON body of the widget API', () async {
      http.handler = (_) => (200, message(8).toJson());

      final created = await service.createMessage(
        ZukkoChatNewMessageRequest(content: 'hi', echoId: 'e1', replyTo: 5),
      );

      expect(created.id, 8);
      expect(http.calls, ['POST $_widget/messages']);
      final body = http.requests.single.data as Map;
      final inner = body['message'] as Map;
      expect(inner['content'], 'hi');
      expect(inner['echo_id'], 'e1');
      expect(inner['reply_to'], 5);
      expect(inner['referer_url'], '');
      expect(inner['timestamp'], isA<String>());
    });

    test('createMessage tolerates the flat response without content_type', () {
      http.handler = (_) => (
        200,
        {
          'id': 9,
          'content': 'x',
          'inbox_id': 1,
          'conversation_id': 7,
          'message_type': 0,
          'created_at': 1626155918,
          'private': false,
        },
      );

      expectLater(
        service
            .createMessage(
              ZukkoChatNewMessageRequest(content: 'x', echoId: 'e'),
            )
            .then((m) => (m.id, m.conversationId, m.contentType)),
        completion((9, 7, null)),
      );
    });

    test(
      'createMessage with attachments sends message[...] multipart',
      () async {
        http.handler = (_) => (200, message(9).toJson());

        final created = await service.createMessage(
          ZukkoChatNewMessageRequest(content: '', echoId: 'e2'),
          attachments: [
            ZukkoChatUpload.bytes(
              name: 'photo.png',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
        );

        expect(created.id, 9);
        expect(http.calls, ['POST $_widget/messages']);
        final form = http.requests.single.data as FormData;
        expect(form.fields.map((f) => f.key), contains('message[echo_id]'));
        expect(
          form.fields.map((f) => f.key),
          isNot(contains('message[content]')),
        );
        final part = form.files.single;
        expect(part.key, 'message[attachments][]');
        expect(part.value.filename, 'photo.png');
        expect(part.value.contentType?.mimeType, 'image/png');
      },
    );

    test('an unsupported attachment fails before any request', () async {
      await expectLater(
        service.createMessage(
          ZukkoChatNewMessageRequest(content: '', echoId: 'e'),
          attachments: [
            ZukkoChatUpload.bytes(name: 'a.exe', bytes: Uint8List(1)),
          ],
        ),
        throwsA(
          isA<ZukkoChatException>().having(
            (e) => e.type,
            'type',
            ZukkoChatExceptionType.sendMessageFailed,
          ),
        ),
      );
      expect(http.requests, isEmpty);
    });

    test('getMessages parses {payload, meta}', () async {
      http.handler = (_) => (
        200,
        {
          'payload': [message(1).toJson(), message(2).toJson()],
          'meta': {'contact_last_seen_at': 10},
        },
      );

      final messages = await service.getMessages();

      expect(messages.map((m) => m.id), [1, 2]);
      expect(http.calls, ['GET $_widget/messages']);
      expect(http.requests.single.queryParameters, isEmpty);
    });

    test('getMessages parses the recorded server response', () async {
      final json = await TestResourceUtil.readJsonResource(
        fileName: 'messages',
      );
      http.handler = (_) => (200, json);

      expect(await service.getMessages(), isNotEmpty);
    });

    test('getMessages(after:) sends the cursor', () async {
      http.handler = (_) => (
        200,
        <String, Object?>{'payload': <Object?>[], 'meta': <String, Object?>{}},
      );

      await service.getMessages(after: 42);
      await service.getMessages(before: 7);

      expect(http.requests[0].queryParameters, {'after': 42});
      expect(http.requests[1].queryParameters, {'before': 7});
    });

    test('getMessages skips a poisoned item and ids <= 0', () async {
      http.handler = (_) => (
        200,
        {
          'payload': [
            message(1).toJson(),
            {'id': 2, 'content': 12345}, // wrong type
            'not even an object',
            {'content': 'no id'},
            {...message(5).toJson(), 'id': -3},
            {...message(4).toJson(), 'created_at': 1e300},
            message(3).toJson(),
          ],
        },
      );

      final messages = await service.getMessages();

      expect(messages.map((m) => m.id), [1, 4, 3]);
    });

    test('getConversation: an object is a conversation', () async {
      http.handler = (_) => (
        200,
        {'id': 3, 'inbox_id': 1, 'contact_last_seen_at': 5, 'status': 'open'},
      );

      final conversation = await service.getConversation();

      expect(conversation!.id, 3);
      expect(conversation.status, 'open');
      expect(http.calls, ['GET $_widget/conversations']);
    });

    test('getConversation: {} means no conversation yet', () async {
      http.handler = (_) => (200, <String, Object?>{});

      expect(await service.getConversation(), isNull);
    });

    test('toggleTyping and updateLastSeen are marked noRecover', () async {
      await service.toggleTyping(true);
      await service.toggleTyping(false);
      await service.updateLastSeen();

      expect(http.calls, [
        'POST $_widget/conversations/toggle_typing',
        'POST $_widget/conversations/toggle_typing',
        'POST $_widget/conversations/update_last_seen',
      ]);
      expect(http.requests[0].queryParameters, {'typing_status': 'on'});
      expect(http.requests[1].queryParameters, {'typing_status': 'off'});
      expect(http.requests.every((r) => r.extra['noRecover'] == true), isTrue);
    });
  });

  group('failures map to the call-specific typed exception', () {
    final calls =
        <
          String,
          (
            ZukkoChatExceptionType,
            Future<void> Function(ZukkoChatClientService),
          )
        >{
          'createMessage': (
            ZukkoChatExceptionType.sendMessageFailed,
            (s) => s.createMessage(
              ZukkoChatNewMessageRequest(content: 'a', echoId: 'b'),
            ),
          ),
          'getMessages': (
            ZukkoChatExceptionType.getMessagesFailed,
            (s) => s.getMessages(),
          ),
          'getConversation': (
            ZukkoChatExceptionType.getConversationFailed,
            (s) => s.getConversation(),
          ),
        };

    for (final entry in calls.entries) {
      final (type, call) = entry.value;

      test('${entry.key}: HTTP 500', () async {
        http.handler = (_) => (500, {'error': 'server'});

        await expectLater(
          call(service),
          throwsA(
            isA<ZukkoChatException>().having((e) => e.type, 'type', type),
          ),
        );
      });

      test('${entry.key}: malformed body', () async {
        http.handler = (_) => (200, 'garbage');

        await expectLater(
          call(service),
          throwsA(
            isA<ZukkoChatException>().having((e) => e.type, 'type', type),
          ),
        );
      });
    }
  });

  group('parseMessagesPage', () {
    test('reads payload of {payload, meta} and tolerates a bare list', () {
      final item = {'id': 3, 'content': 'x', 'created_at': 1626155918};

      expect(
        parseMessagesPage({
          'payload': [item],
          'meta': <String, Object?>{},
        }).map((m) => m.id),
        [3],
      );
      expect(parseMessagesPage([item]).map((m) => m.id), [3]);
      expect(
        () => parseMessagesPage(<String, Object?>{'meta': null}),
        throwsFormatException,
      );
    });
  });
}
