import 'dart:io';

import 'package:chatwoot_sdk/src/data/models/chatwoot_contact.dart';
import 'package:chatwoot_sdk/src/data/models/chatwoot_message.dart';
import 'package:chatwoot_sdk/src/data/remote/realtime/chatwoot_action_data.dart';
import 'package:chatwoot_sdk/src/data/models/chatwoot_event_message_user.dart';
import 'package:chatwoot_sdk/src/data/remote/realtime/chatwoot_event.dart';
import 'package:chatwoot_sdk/src/shared/json_converters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatwootContact.fromJson', () {
    test('accepts null name and email (anonymous contact)', () {
      final contact = ChatwootContact.fromJson({
        'id': 1,
        'source_id': 'abc',
        'pubsub_token': 't',
        'name': null,
        'email': null,
      });

      expect(contact.name, isNull);
      expect(contact.email, isNull);
      expect(contact.contactIdentifier, 'abc');
    });

    test('accepts absent name, email and source_id', () {
      final contact = ChatwootContact.fromJson({'id': 1});

      expect(contact.contactIdentifier, isNull);
      expect(contact.pubsubToken, isNull);
    });
  });

  group('ChatwootMessage.fromJson', () {
    test('accepts null message_type, conversation_id and created_at', () {
      final message = ChatwootMessage.fromJson({
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
      expect(() => ChatwootMessage.fromJson({'id': 1}), returnsNormally);
    });

    test('parses numeric strings and unix timestamps', () {
      final message = ChatwootMessage.fromJson({
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
      final message = ChatwootMessage.fromJson({
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

      final ChatwootMessage message = data.getMessage();

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
  group('ChatwootMessage.isMine', () {
    for (final (type, mine) in [
      (0, true), // incoming: written by the contact
      (1, false), // outgoing: agent
      (2, false), // activity
      (3, false), // template
      (null, false),
    ]) {
      test('message_type $type -> $mine', () {
        final message = ChatwootMessage.fromJson({
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
      expect(ChatwootActionType.update_presence.wire, 'update_presence');
      expect(ChatwootActionType.values, [ChatwootActionType.update_presence]);
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
            .contains('name: chatwoot_sdk')) {
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

  test('ChatwootEventMessageUser round-trips JSON and keeps its Hive id', () {
    final user = ChatwootEventMessageUser.fromJson({
      'id': '5',
      'name': 'Ann',
      'avatar_url': 'https://a/x.png',
    });

    expect(user.id, 5);
    expect(user.toJson()['avatar_url'], 'https://a/x.png');
    expect(ChatwootEventMessageUserAdapter().typeId, 4);
  });
}
