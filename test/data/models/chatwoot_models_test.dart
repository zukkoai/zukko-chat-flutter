import 'dart:io';

import 'package:zukko_chat_flutter/src/data/models/chatwoot_contact.dart';
import 'package:zukko_chat_flutter/src/data/models/chatwoot_conversation.dart';
import 'package:zukko_chat_flutter/src/data/models/chatwoot_message.dart';
import 'package:zukko_chat_flutter/src/data/models/chatwoot_user.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/chatwoot_action_data.dart';
import 'package:zukko_chat_flutter/src/data/models/chatwoot_event_message_user.dart';
import 'package:zukko_chat_flutter/src/data/remote/realtime/chatwoot_event.dart';
import 'package:zukko_chat_flutter/src/shared/json_converters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZukkoChatContact.fromJson', () {
    test('accepts null name and email (anonymous contact)', () {
      final contact = ZukkoChatContact.fromJson({
        'id': 1,
        'identifier': 'abc',
        'pubsub_token': 't',
        'name': null,
        'email': null,
      });

      expect(contact.name, isNull);
      expect(contact.email, isNull);
      expect(contact.contactIdentifier, 'abc');
    });

    test('accepts absent name, email and identifier', () {
      final contact = ZukkoChatContact.fromJson({'id': 1});

      expect(contact.contactIdentifier, isNull);
      expect(contact.pubsubToken, isNull);
    });
  });

  group('ZukkoChatContact widget fields', () {
    test('reads phone_number; the JWT never goes through JSON', () {
      final fromServer = ZukkoChatContact.fromJson({
        'id': 1,
        'phone_number': '+998901234567',
        'auth_token': 'jwt-secret', // not a contact field: ignored
      });
      const stored = ZukkoChatContact(
        id: 1,
        contactIdentifier: 'u',
        pubsubToken: 'p',
        name: null,
        email: null,
        authToken: 'jwt-secret',
      );

      expect(fromServer.phoneNumber, '+998901234567');
      expect(fromServer.authToken, isNull);
      expect(stored.toJson().toString(), isNot(contains('jwt-secret')));
      expect(stored.toString(), isNot(contains('jwt-secret')));
      expect(stored.copyWith(authToken: 'new').authToken, 'new');
      expect(stored, isNot(stored.copyWith(authToken: 'new')));
    });
  });

  group('ZukkoChatConversation.fromJson', () {
    test('GET /conversations: no contact, no messages, status kept', () {
      final c = ZukkoChatConversation.fromJson({
        'id': 4,
        'inbox_id': 1,
        'contact_last_seen_at': 0,
        'status': 'open',
      });

      expect(c.contact, isNull);
      expect(c.messages, isEmpty);
      expect(c.status, 'open');
    });

    test('{} parses to id 0 instead of throwing', () {
      expect(ZukkoChatConversation.fromJson({}).id, 0);
    });
  });

  group('ZukkoChatUser', () {
    test('phone_number is in the set_user body, nulls are not', () {
      final json = const ZukkoChatUser(
        identifier: 'u',
        phoneNumber: '+998901234567',
      ).toJson();

      expect(json, {'identifier': 'u', 'phone_number': '+998901234567'});
    });

    test('the phone is persistable, the hash is not', () {
      final persisted = const ZukkoChatUser(
        identifier: 'u',
        identifierHash: 'h',
        phoneNumber: '+1',
      ).toPersistable();

      expect(persisted.phoneNumber, '+1');
      expect(persisted.identifierHash, isNull);
    });
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

  group('ZukkoChatMessage.fromJson', () {
    test('accepts null message_type, conversation_id and created_at', () {
      final message = ZukkoChatMessage.fromJson({
        'id': 5,
        'content': 'hi',
        'message_type': null,
        'conversation_id': null,
        'created_at': null,
      });

      expect(message.messageType, isNull);
      expect(message.conversationId, isNull);
      // the UI feeds this to DateTime.parse
      expect(() => DateTime.parse(message.createdAt), returnsNormally);
    });

    test('accepts absent optional keys', () {
      expect(() => ZukkoChatMessage.fromJson({'id': 1}), returnsNormally);
    });

    test('parses numeric strings and unix timestamps', () {
      final message = ZukkoChatMessage.fromJson({
        'id': '12',
        'message_type': '1',
        'conversation_id': '3',
        'created_at': 1626155918,
      });

      expect(message.id, 12);
      expect(message.messageType, 1);
      expect(message.conversationId, 3);
      expect(
        DateTime.parse(message.createdAt).millisecondsSinceEpoch,
        1626155918 * 1000,
      );
    });

    test('keeps an already formatted created_at', () {
      final message = ZukkoChatMessage.fromJson({
        'id': 1,
        'created_at': '2021-07-13T06:58:38.000Z',
      });

      expect(message.createdAt, '2021-07-13T06:58:38.000Z');
    });
  });

  group('ChatwootEventMessageData.getMessage', () {
    test('returns a typed message and tolerates null fields', () {
      final data = ChatwootEventMessageData.fromJson({
        'id': 3,
        'content': 'x',
        'message_type': null,
        'conversation_id': null,
        'created_at': null,
      });

      final ZukkoChatMessage message = data.getMessage();

      expect(message.id, 3);
      expect(message.messageType, isNull);
    });
  });

  group('json converters', () {
    test('intFromJson', () {
      expect(intFromJson(4), 4);
      expect(intFromJson(4.0), 4);
      expect(intFromJson('4'), 4);
      expect(intFromJson('x'), isNull);
      expect(intFromJson(null), isNull);
      expect(intFromJson([]), isNull);
    });

    test('idFromJson falls back to 0', () {
      expect(idFromJson(null), 0);
      expect(idFromJson('nope'), 0);
      expect(idFromJson('9'), 9);
    });
  });

  // S14: used to be `messageType != 1`
  group('ZukkoChatMessage.isMine', () {
    for (final (type, mine) in [
      (0, true), // incoming: written by the contact
      (1, false), // outgoing: agent
      (2, false), // activity
      (3, false), // template
      (null, false),
    ]) {
      test('message_type $type -> $mine', () {
        final message = ZukkoChatMessage.fromJson({
          'id': 1,
          'message_type': type,
        });

        expect(message.isMine, mine);
      });
    }
  });

  // S23 / S19: one table maps wire names both ways
  group('event wire names', () {
    test('round trip for every known event', () {
      for (final type in ChatwootEventMessageType.values) {
        expect(ChatwootEventMessageType.byWire(type.wire), type);
        expect(eventMessageTypeToJson(type), type.wire);
      }
      expect(
        ChatwootEventMessage(event: ChatwootEventMessageType.message_created)
            .toJson()['event'],
        'message.created',
      );
    });

    test('unknown or malformed names are null, not a crash', () {
      expect(ChatwootEventMessageType.byWire('contact.merged'), isNull);
      expect(ChatwootEventMessageType.byWire(5), isNull);
      expect(ChatwootEventMessageType.byWire(null), isNull);
    });

    test('action wire names', () {
      expect(ZukkoChatActionType.update_presence.wire, 'update_presence');
      expect(ZukkoChatActionType.values, [ZukkoChatActionType.update_presence]);
    });
  });

  test('typing events expose is_private', () {
    final data = ChatwootEventMessageData.fromJson({'is_private': true});

    expect(data.isPrivate, isTrue);
  });

  // F15: models used to import remote/realtime, which imports models back
  test('models/ does not import anything from remote/', () {
    // `flutter test` cannot resolve package: URIs to files; walk up from the
    // working directory to the package root instead (works from any subdir)
    var root = Directory.current;
    while (!File('${root.path}/pubspec.yaml').existsSync() ||
        !File('${root.path}/pubspec.yaml')
            .readAsStringSync()
            .contains('name: zukko_chat_flutter')) {
      expect(root.parent.path, isNot(root.path), reason: 'package root');
      root = root.parent;
    }
    final models = Directory('${root.path}/lib/src/data/models');

    final offenders = [
      for (final file in models.listSync().whereType<File>())
        if (file.path.endsWith('.dart') &&
            file.readAsStringSync().contains(RegExp(r"import '[^']*remote/")))
          file.uri.pathSegments.last,
    ];

    expect(offenders, isEmpty);
  });

  test('ZukkoChatEventMessageUser round-trips JSON and keeps its Hive id', () {
    final user = ZukkoChatEventMessageUser.fromJson({
      'id': '5',
      'name': 'Ann',
      'avatar_url': 'https://a/x.png',
    });

    expect(user.id, 5);
    expect(user.toJson()['avatar_url'], 'https://a/x.png');
    expect(ZukkoChatEventMessageUserAdapter().typeId, 4);
  });
}
