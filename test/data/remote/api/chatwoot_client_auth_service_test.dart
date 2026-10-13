import 'package:chatwoot_sdk/src/core/chatwoot_client_exception.dart';
import 'package:chatwoot_sdk/src/data/remote/api/chatwoot_client_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../utils/fake_http.dart';
import '../../../utils/fixtures.dart';
import '../../../utils/test_resources_util.dart';

void main() {
  late FakeHttpAdapter http;
  late ChatwootClientAuthServiceImpl service;

  setUp(() {
    http = FakeHttpAdapter((_) => (200, {}));
    service = ChatwootClientAuthServiceImpl(dio: dioWith(http));
  });

  test('createNewContact posts the user and parses the contact', () async {
    http.handler = (_) => (200, contact().toJson());

    final created = await service.createNewContact('inbox', user());

    expect(created, contact());
    expect(http.calls, ['POST /public/api/v1/inboxes/inbox/contacts']);
    expect(http.requests.single.data, user().toJson());
  });

  // SEC9
  test('identifiers are encoded into one path segment each', () async {
    http.handler = (_) => (200, contact().toJson());

    await service.createNewContact('in/../box?x#', null);

    expect(http.calls, [
      'POST /public/api/v1/inboxes/in%2F..%2Fbox%3Fx%23/contacts',
    ]);
  });

  test('createNewContact without a user sends no body', () async {
    http.handler = (_) => (200, contact().toJson());

    await service.createNewContact('inbox', null);

    expect(http.requests.single.data, isNull);
  });

  test(
    'createNewConversation posts to the contact and parses the result',
    () async {
      http.handler = (_) => (200, <String, dynamic>{});
      final json = await TestResourceUtil.readJsonResource(
        fileName: 'conversation',
      );
      http.handler = (_) => (200, json);

      final created = await service.createNewConversation('inbox', 'src');

      expect(created.id, 7);
      expect(http.calls, [
        'POST /public/api/v1/inboxes/inbox/contacts/src/conversations',
      ]);
    },
  );

  group('failures are mapped to typed exceptions', () {
    test('contact: server error', () async {
      http.handler = (_) => (500, {'error': 'x'});

      expect(
        service.createNewContact('inbox', null),
        throwsA(
          isA<ChatwootClientException>().having(
            (e) => e.type,
            'type',
            ChatwootClientExceptionType.CREATE_CONTACT_FAILED,
          ),
        ),
      );
    });

    test('conversation: server error', () async {
      http.handler = (_) => (404, {});

      expect(
        service.createNewConversation('inbox', 'src'),
        throwsA(
          isA<ChatwootClientException>().having(
            (e) => e.type,
            'type',
            ChatwootClientExceptionType.CREATE_CONVERSATION_FAILED,
          ),
        ),
      );
    });

    test('contact: malformed body', () async {
      http.handler = (_) => (200, 'not an object');

      expect(
        service.createNewContact('inbox', null),
        throwsA(
          isA<ChatwootClientException>().having(
            (e) => e.type,
            'type',
            ChatwootClientExceptionType.CREATE_CONTACT_FAILED,
          ),
        ),
      );
    });
  });
}
