import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce/src/binary/binary_reader_impl.dart';
import 'package:hive_ce/src/binary/binary_writer_impl.dart';
import 'package:zukko_chat_flutter/src/data/local/hive_adapters.dart';
import 'package:zukko_chat_flutter/src/data/local/hive_database.dart';
import 'package:zukko_chat_flutter/src/data/local/hive_type_ids.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:zukko_chat_flutter/src/data/local/zukko_chat_box_names.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_attachment.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_contact.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_conversation.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_event_message_user.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_message.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_user.dart';

import '../../utils/fixtures.dart';
import '../../utils/hive_test_env.dart';

ZukkoChatMessage _msg(
  int id, {
  Map<String, dynamic>? attrs,
  List<ZukkoChatAttachment>? files,
}) => ZukkoChatMessage(
  id: id,
  content: 'c',
  messageType: 1,
  contentType: 'text',
  contentAttributes: attrs,
  createdAt: '2024-01-01T10:00:00.000Z',
  conversationId: 7,
  attachments: files,
  sender: null,
);

void main() {
  final env = HiveTestEnv();
  setUpAll(env.setUpAll);
  setUp(HiveDatabase.takeRecreated); // drop leftovers of earlier tests
  tearDown(env.tearDown);
  tearDownAll(env.tearDownAll);

  group('#19 conversation without embedded copies', () {
    test('saved and loaded: only id, inbox and status', () async {
      await env.open();
      final storage = LocalStorage.persisted('k');
      const c = ZukkoChatConversation(id: 4, inboxId: 1, status: 'open');

      await storage.conversation.save(c);

      expect(storage.conversation.get(), c);
    });

    test('an old record with embedded messages and contact (fields 2, 3) '
        'still loads', () {
      final w = BinaryWriterImpl(Hive)
        ..writeByte(5)
        ..writeByte(0)
        ..write(4)
        ..writeByte(1)
        ..write(1)
        ..writeByte(2)
        ..write(<dynamic>[
          {'id': 1},
        ])
        ..writeByte(3)
        ..write({'name': 'old contact'})
        ..writeByte(4)
        ..write('resolved');
      registerZukkoChatAdapters();

      final c = ZukkoChatConversationAdapter().read(
        BinaryReaderImpl(w.toBytes(), Hive),
      );

      expect(
        c,
        const ZukkoChatConversation(id: 4, inboxId: 1, status: 'resolved'),
      );
    });
  });

  group('#20 typed attachments and attributes', () {
    test('full attachment payload', () {
      final a = attachmentsFromJson([
        {
          'id': 3,
          'message_id': '9',
          'file_type': 'image',
          'account_id': 1,
          'extension': 'png',
          'data_url': 'https://h/a.png',
          'thumb_url': 'https://h/t.png',
          'file_size': 2048,
          'width': 640,
          'height': 480,
        },
      ])!.single;

      expect(a.id, 3);
      expect(a.messageId, 9);
      expect(a.fileType, 'image');
      expect(a.dataUrl, 'https://h/a.png');
      expect(a.thumbUrl, 'https://h/t.png');
      expect(a.fileSize, 2048);
      expect([a.width, a.height], [640, 480]);
    });

    test('partial and wrongly typed fields become null', () {
      final a = attachmentsFromJson([
        {'file_type': 5, 'data_url': 'https://h/a', 'file_size': 'big'},
      ])!.single;

      expect(a.dataUrl, 'https://h/a');
      expect(a.fileType, isNull);
      expect(a.fileSize, isNull);
      expect(a.id, isNull);
    });

    test('garbage elements are skipped, a non-list is null', () {
      final list = attachmentsFromJson([
        'x',
        null,
        7,
        {'data_url': 'https://h/ok'},
      ])!;

      expect(list.map((e) => e.dataUrl), ['https://h/ok']);
      expect(attachmentsFromJson('oops'), isNull);
      expect(attachmentsFromJson(null), isNull);
    });

    test('message JSON: content_attributes map, junk becomes null', () {
      final base = {'id': 1, 'created_at': 1700000000};

      final ok = ZukkoChatMessage.fromJson({
        ...base,
        'content_attributes': {'a': 1},
        'attachments': [
          {'file_type': 'file'},
        ],
      });
      final bad = ZukkoChatMessage.fromJson({
        ...base,
        'content_attributes': [1, 2],
        'attachments': 'x',
      });

      expect(ok.contentAttributes, {'a': 1});
      expect(ok.attachments!.single.fileType, 'file');
      expect(bad.contentAttributes, isNull);
      expect(bad.attachments, isNull);
    });

    test('user customAttributes is a map; junk becomes null', () {
      expect(
        ZukkoChatUser.fromJson({
          'custom_attributes': {'plan': 'pro'},
        }).customAttributes,
        {'plan': 'pro'},
      );
      expect(
        ZukkoChatUser.fromJson({'custom_attributes': 'x'}).customAttributes,
        isNull,
      );
    });

    test('round-trip through Hive keeps attachments and attributes', () async {
      await env.open();
      final storage = LocalStorage.persisted('k');
      final m = _msg(
        1,
        attrs: {
          'nested': {'a': 1},
        },
        files: const [
          ZukkoChatAttachment(
            id: 2,
            fileType: 'audio',
            dataUrl: 'https://h/a.ogg',
            fileSize: 10,
          ),
        ],
      );

      await storage.messages.saveMessage(m);
      await Hive.close();
      await env.open();

      final back = LocalStorage.persisted('k').messages.getMessage(1)!;
      expect(back, m);
      expect(back.contentAttributes, isA<Map<String, dynamic>>());
    });

    test('an old record (attachments as raw maps, attributes as a Hive map) '
        'loads', () {
      final w = BinaryWriterImpl(Hive)
        ..writeByte(9)
        ..writeByte(0)
        ..write(5)
        ..writeByte(1)
        ..write('hi')
        ..writeByte(2)
        ..write(1)
        ..writeByte(3)
        ..write('text')
        ..writeByte(4)
        ..write(<dynamic, dynamic>{'k': 'v'})
        ..writeByte(5)
        ..write('2024-01-01T10:00:00.000Z')
        ..writeByte(6)
        ..write(7)
        ..writeByte(7)
        ..write(<dynamic>[
          <dynamic, dynamic>{'file_type': 'image', 'data_url': 'https://h/x'},
          'junk',
        ])
        ..writeByte(8)
        ..write(null);
      registerZukkoChatAdapters();

      final m = ZukkoChatMessageAdapter().read(
        BinaryReaderImpl(w.toBytes(), Hive),
      );

      expect(m.contentAttributes, {'k': 'v'});
      expect(m.attachments!.single.dataUrl, 'https://h/x');
    });
  });

  group('#23 key and box mismatch', () {
    test(
      '(a) key present, boxes missing: key is reused, store works',
      () async {
        env.keys.key = Hive.generateSecureKey();
        final key = List.of(env.keys.key!);

        await env.open();
        await LocalStorage.persisted('k').contact.save(contact());

        expect(env.keys.key, key);
        expect(env.keys.writes, 0);
        expect(HiveDatabase.takeRecreated(), isEmpty);
      },
    );

    test(
      '(b) boxes present, a different key: boxes wiped, new key, works',
      () async {
        await env.open();
        await LocalStorage.persisted('k').contact.save(contact());
        await LocalStorage.persisted('k').messages.saveMessage(_msg(1));
        await LocalStorage.persisted('k').conversation
            .save(const ZukkoChatConversation(id: 1, inboxId: 1));
        await Hive.close();
        env.keys.key = Hive.generateSecureKey(); // restored device, other key

        await env.open();

        expect(HiveDatabase.takeRecreated().toSet(), {
          ZukkoChatBoxNames.contacts,
          ZukkoChatBoxNames.conversations,
          ZukkoChatBoxNames.messages,
        });
        final storage = LocalStorage.persisted('k');
        expect(storage.contact.get(), isNull);
        await storage.contact.save(contact());
        expect(storage.contact.get(), contact());
      },
    );

    test('(b) wipes only SDK boxes, a host box stays intact', () async {
      await env.open();
      await LocalStorage.persisted('k').contact.save(contact());
      final host = await Hive.openBox<String>('host_app_box');
      await host.put('a', 'keep');
      await Hive.close();
      env.keys.key = null;

      await env.open();
      final hostAgain = await Hive.openBox<String>('host_app_box');

      expect(hostAgain.get('a'), 'keep');
      expect(LocalStorage.persisted('k').contact.get(), isNull);
    });
  });

  group('type ids 210-214', () {
    test('ids are 210-214 and adapters are registered on them', () async {
      await env.open();

      expect(
        [
          zukkoChatContactHiveTypeId,
          zukkoChatConversationHiveTypeId,
          zukkoChatMessageHiveTypeId,
          zukkoChatUserHiveTypeId,
          zukkoChatEventUserHiveTypeId,
        ],
        [210, 211, 212, 213, 214],
      );
      for (final id in [210, 211, 212, 213, 214]) {
        expect(Hive.isAdapterRegistered(id), isTrue, reason: 'id $id');
      }
      for (final id in [0, 1, 2, 3, 4]) {
        expect(Hive.isAdapterRegistered(id), isFalse, reason: 'id $id');
      }
    });

    test('a box written with the old ids 0-4 is wiped cleanly', () async {
      await env.open();
      final name = ZukkoChatBoxNames.conversations;
      final cipher = HiveAesCipher(env.keys.key!);
      await Hive.close();
      // write a record under the old type id 1, as an older build did
      Hive.resetAdapters();
      Hive.registerAdapter(_OldConversationAdapter());
      final box = await Hive.openBox<Object>(name, encryptionCipher: cipher);
      await box.put('k', _OldConversation());
      await box.close();
      // the current build only knows 210-214
      Hive.resetAdapters();
      Hive
        ..registerAdapter(ZukkoChatContactAdapter())
        ..registerAdapter(ZukkoChatConversationAdapter())
        ..registerAdapter(ZukkoChatMessageAdapter())
        ..registerAdapter(ZukkoChatUserAdapter())
        ..registerAdapter(ZukkoChatEventMessageUserAdapter());

      await env.open();

      expect(HiveDatabase.takeRecreated(), [name]);
      expect(Hive.box<ZukkoChatConversation>(name).isEmpty, isTrue);
      final storage = LocalStorage.persisted('k');
      const c = ZukkoChatConversation(id: 1, inboxId: 1);
      await storage.conversation.save(c);
      expect(storage.conversation.get(), c);
    });
  });

  group('wipes leave no old frames on disk', () {
    Future<int> fillContacts() async {
      final storage = LocalStorage.persisted('k');
      for (var i = 0; i < 20; i++) {
        await storage.contact.save(contact());
      }
      return File(Hive.box<ZukkoChatContact>(ZukkoChatBoxNames.contacts).path!)
          .lengthSync();
    }

    int contactsFileSize() =>
        File(Hive.box<ZukkoChatContact>(ZukkoChatBoxNames.contacts).path!)
            .lengthSync();

    test('clearInstanceFamily compacts the box file', () async {
      await env.open();
      final before = await fillContacts();

      await HiveDatabase.clearInstanceFamily('k');

      expect(contactsFileSize(), lessThan(before ~/ 10));
    });
  });
}

class _OldConversation {}

class _OldConversationAdapter extends TypeAdapter<_OldConversation> {
  @override
  final typeId = 1;

  @override
  _OldConversation read(BinaryReader reader) => _OldConversation();

  @override
  void write(BinaryWriter writer, _OldConversation obj) {
    writer.writeByte(0);
  }
}
