import 'dart:convert';
import 'dart:io';

import 'package:zukko_chat_flutter/src/data/local/instance_key.dart';
import 'package:zukko_chat_flutter/src/data/local/dao/zukko_chat_messages_dao.dart';
import 'package:zukko_chat_flutter/src/data/local/hive_database.dart';
import 'package:zukko_chat_flutter/src/data/local/hive_type_ids.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:zukko_chat_flutter/src/data/local/zukko_chat_box_names.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_contact.dart';
import 'package:zukko_chat_flutter/src/data/models/zukko_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../utils/fixtures.dart';
import '../../utils/hive_test_env.dart';

/// One suite, run against both storage implementations: they must behave
/// identically (same order, same isolation, same clear semantics).
void main() {
  final env = HiveTestEnv();
  setUpAll(env.setUpAll);
  tearDown(env.tearDown);
  tearDownAll(env.tearDownAll);

  final implementations = <String, LocalStorage Function(String key)>{
    'persisted (Hive)': LocalStorage.persisted,
    'in-memory': (_) => LocalStorage.inMemory(),
  };

  for (final entry in implementations.entries) {
    group('LocalStorage ${entry.key}', () {
      late LocalStorage Function(String key) make;

      setUp(() async {
        await env.open();
        make = entry.value;
      });

      test('contact and conversation round-trip and delete', () async {
        final storage = make('k');
        expect(storage.contact.get(), isNull);

        await storage.contact.save(contact());
        await storage.conversation.save(conversation());

        expect(storage.contact.get(), contact());
        expect(storage.conversation.get()!.id, 7);

        await storage.contact.delete();
        expect(storage.contact.get(), isNull);
      });

      test('saving again overwrites', () async {
        final storage = make('k');
        await storage.conversation.save(conversation(id: 1));
        await storage.conversation.save(conversation(id: 2));

        expect(storage.conversation.get()!.id, 2);
      });

      // P11: contact without an identifier used to crash with a null check
      test('an anonymous contact (no identifier) can be stored', () async {
        final storage = make('k');

        await storage.contact.save(contact(identifier: null));

        expect(storage.contact.get()!.contactIdentifier, isNull);
      });

      // P8: persisted was newest-first, in-memory oldest-first
      test(
        'messages come back oldest first regardless of insert order',
        () async {
          final storage = make('k');
          await storage.messages.saveMessage(
            message(3, createdAt: '2024-01-03'),
          );
          await storage.messages.saveMessage(
            message(1, createdAt: '2024-01-01'),
          );
          await storage.messages.saveAllMessages([
            message(2, createdAt: '2024-01-02'),
          ]);

          expect(storage.messages.getMessages().map((m) => m.id), [1, 2, 3]);
        },
      );

      test('messages with the same timestamp are ordered by id', () async {
        final storage = make('k');
        await storage.messages.saveAllMessages([
          message(9, createdAt: '2024-01-01'),
          message(4, createdAt: '2024-01-01'),
        ]);

        expect(storage.messages.getMessages().map((m) => m.id), [4, 9]);
      });

      test('saving a message with an existing id replaces it', () async {
        final storage = make('k');
        await storage.messages.saveMessage(message(1, content: 'old'));
        await storage.messages.saveMessage(message(1, content: 'new'));

        expect(storage.messages.getMessages(), hasLength(1));
        expect(storage.messages.getMessage(1)!.content, 'new');
      });

      test('getMessage finds a message by id', () async {
        final storage = make('k');
        await storage.messages.saveAllMessages([message(1), message(2)]);

        expect(storage.messages.getMessage(1)!.id, 1);
        expect(storage.messages.getMessage(3), isNull);
      });

      // F11
      test('messages are ordered by instant, not by string, and ids by '
          'number', () async {
        final storage = make('k');
        await storage.messages.saveAllMessages([
          // 10:00 +02:00 is 08:00 UTC, i.e. BEFORE 09:00 UTC although the
          // strings compare the other way round
          message(1, createdAt: '2024-01-01T09:00:00Z'),
          message(2, createdAt: '2024-01-01T10:00:00+02:00'),
          message(10, createdAt: '2024-01-01T12:00:00Z'),
          message(9, createdAt: '2024-01-01T12:00:00Z'),
        ]);

        expect(storage.messages.getMessages().map((m) => m.id), [2, 1, 9, 10]);
      });

      // P9: ids were global, so two instances overwrote each other
      test('instances are isolated from each other', () async {
        final a = make('a');
        final b = make('b');

        await a.conversation.save(conversation(id: 1));
        await b.conversation.save(conversation(id: 1));
        await a.contact.save(contact(identifier: 'same'));
        await b.contact.save(contact(identifier: 'same', pubsubToken: 'other'));
        await a.messages.saveMessage(message(1, content: 'from a'));
        await b.messages.saveMessage(message(1, content: 'from b'));

        expect(a.contact.get()!.pubsubToken, 'token-1');
        expect(b.contact.get()!.pubsubToken, 'other');
        expect(a.messages.getMessage(1)!.content, 'from a');
        expect(b.messages.getMessage(1)!.content, 'from b');
        expect(a.messages.getMessages(), hasLength(1));

        await a.messages.clear();
        await a.conversation.delete();

        expect(a.messages.getMessages(), isEmpty);
        expect(b.messages.getMessages(), hasLength(1));
        expect(b.conversation.get(), isNotNull);
      });

      test('clear() keeps the contact unless asked', () async {
        final storage = make('k');
        await storage.contact.save(contact());
        await storage.conversation.save(conversation());
        await storage.messages.saveMessage(message(1));

        await storage.clear(clearContact: false);

        expect(storage.conversation.get(), isNull);
        expect(storage.messages.getMessages(), isEmpty);
        expect(storage.contact.get(), isNotNull);

        await storage.clear();

        expect(storage.contact.get(), isNull);
      });
    });
  }

  group('persisted storage specifics', () {
    setUp(env.open);

    test('data survives closing and reopening the boxes', () async {
      final key = zukkoChatInstanceKey(
        baseUrl: 'https://a',
        websiteToken: 'in',
        userIdentifier: 'u',
      );
      await LocalStorage.persisted(key).contact.save(contact());
      await LocalStorage.persisted(key).messages.saveMessage(message(1));

      await Hive.close();
      await HiveDatabase.openDB();

      final storage = LocalStorage.persisted(key);
      expect(storage.contact.get(), contact());
      expect(storage.messages.getMessages(), hasLength(1));
    });

    test('openDB is idempotent', () async {
      await LocalStorage.persisted('k').contact.save(contact());

      await HiveDatabase.openDB();
      await HiveDatabase.openDB();

      expect(LocalStorage.persisted('k').contact.get(), isNotNull);
    });

    // An instance key that is a prefix of another must not see its messages.
    test('instance keys that are prefixes do not leak messages', () async {
      final short = LocalStorage.persisted(
        zukkoChatInstanceKey(
          baseUrl: 'https://a',
          websiteToken: 'in',
          userIdentifier: 'u',
        ),
      );
      final long = LocalStorage.persisted(
        zukkoChatInstanceKey(
          baseUrl: 'https://a',
          websiteToken: 'in|m|1',
          userIdentifier: 'u',
        ),
      );

      await long.messages.saveMessage(message(1));

      expect(short.messages.getMessages(), isEmpty);
      expect(long.messages.getMessages(), hasLength(1));
    });

    test('clearAllPersisted wipes every instance', () async {
      await LocalStorage.persisted('a').contact.save(contact());
      await LocalStorage.persisted('b').messages.saveMessage(message(1));

      await HiveDatabase.clearAll();

      expect(LocalStorage.persisted('a').contact.get(), isNull);
      expect(LocalStorage.persisted('b').messages.getMessages(), isEmpty);
    });

    test('box names are pinned (they are file names on devices)', () {
      expect(
        ZukkoChatBoxNames.contacts,
        'ChatwootContactBoxNames.CONTACTS.enc',
      );
      expect(
        ZukkoChatBoxNames.conversations,
        'ChatwootConversationBoxNames.CONVERSATIONS.enc',
      );
      expect(
        ZukkoChatBoxNames.messages,
        'ChatwootMessagesBoxNames.MESSAGES.enc',
      );
      expect(ZukkoChatBoxNames.users, 'ChatwootUserBoxNames.USERS.enc');
    });

    test('the secure-storage key and the type ids are pinned', () {
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
    });

    test('a full wipe also removes the retired users box', () async {
      final users = await Hive.openBox<String>(ZukkoChatBoxNames.users);
      await users.put('k', 'old PII');
      await users.close();
      expect(await Hive.boxExists(ZukkoChatBoxNames.users), isTrue);

      await HiveDatabase.clearAll();

      expect(await Hive.boxExists(ZukkoChatBoxNames.users), isFalse);
    });

    test('only the newest maxStored messages are kept per instance', () async {
      final storage = LocalStorage.persisted('k');
      final many = [
        for (var i = 1; i <= PersistedZukkoChatMessagesDao.maxStored + 5; i++)
          message(
            i,
            createdAt: '2024-01-01T00:00:00.${i.toString().padLeft(3, '0')}Z',
          ),
      ];

      await storage.messages.saveAllMessages(many);

      final kept = storage.messages.getMessages();
      expect(PersistedZukkoChatMessagesDao.maxStored, 20);
      expect(kept, hasLength(20));
      expect(kept.first.id, 6);
      expect(kept.last.id, 25);
    });
  });

  // SEC3
  group('encryption at rest', () {
    setUp(env.open);

    Future<List<int>> bytesOf(Box<dynamic> box) async {
      await box.flush();
      return File(box.path!).readAsBytes();
    }

    bool contains(List<int> haystack, String needle) =>
        latin1.decode(haystack).contains(needle);

    test('secrets are not readable in the box files', () async {
      final storage = LocalStorage.persisted('k');
      await storage.contact.save(
        contact(
          identifier: 'SOURCE-ID-SECRET',
          pubsubToken: 'PUBSUB-SECRET',
          authToken: 'JWT-SECRET',
        ),
      );
      await storage.messages.saveMessage(message(1, content: 'PRIVATE-TEXT'));

      final contactBytes = await bytesOf(
        Hive.box<ZukkoChatContact>(ZukkoChatBoxNames.contacts),
      );
      final messageBytes = await bytesOf(
        Hive.box<ZukkoChatMessage>(ZukkoChatBoxNames.messages),
      );

      expect(contains(contactBytes, 'SOURCE-ID-SECRET'), isFalse);
      expect(contains(contactBytes, 'PUBSUB-SECRET'), isFalse);
      expect(contains(contactBytes, 'JWT-SECRET'), isFalse);
      expect(contains(messageBytes, 'PRIVATE-TEXT'), isFalse);
    });

    test('control: the same data IS readable in a plaintext box', () async {
      final plain = await Hive.openBox<ZukkoChatContact>('plain_control');
      await plain.put(
        'k',
        contact(identifier: 'SOURCE-ID-SECRET', authToken: 'JWT-SECRET'),
      );

      final bytes = await bytesOf(plain);
      expect(contains(bytes, 'SOURCE-ID-SECRET'), isTrue);
      expect(contains(bytes, 'JWT-SECRET'), isTrue);
    });

    test('the key is generated once, 256 bits, and reused', () async {
      final key = env.keys.key!;
      expect(key, hasLength(32));

      await Hive.close();
      await HiveDatabase.openDB();

      expect(env.keys.key, key);
      expect(env.keys.writes, 1);
    });

    test('data is readable after a restart with the same key', () async {
      await LocalStorage.persisted('k').contact
          .save(contact(authToken: 'jwt-1'));

      await Hive.close();
      await HiveDatabase.openDB();

      expect(
        LocalStorage.persisted('k').contact.get(),
        contact(authToken: 'jwt-1'),
      );
    });

    test(
      'a lost key recreates the unreadable boxes instead of failing',
      () async {
        await LocalStorage.persisted('k').contact.save(contact());
        await Hive.close();
        env.keys.key = null; // keystore was reset

        await HiveDatabase.openDB();

        expect(LocalStorage.persisted('k').contact.get(), isNull);
        await LocalStorage.persisted('k').contact.save(contact());
        expect(LocalStorage.persisted('k').contact.get(), isNotNull);
        // reported once, so the app can tell the visitor lost the session
        expect(HiveDatabase.takeRecreated(), isNotEmpty);
        expect(HiveDatabase.takeRecreated(), isEmpty);
      },
    );
  });

  // F9
  group('openDB is serialised', () {
    test('concurrent calls open once, no exception', () async {
      await Future.wait([
        HiveDatabase.openDB(),
        HiveDatabase.openDB(),
        HiveDatabase.openDB(),
      ]);

      expect(env.keys.writes, 1);
      await LocalStorage.persisted('k').contact.save(contact());
      expect(LocalStorage.persisted('k').contact.get(), isNotNull);
    });
  });

  group('zukkoChatInstanceKey hash (SEC5)', () {
    String key({String? hash}) => zukkoChatInstanceKey(
      baseUrl: 'https://a',
      websiteToken: 'in',
      userIdentifier: 'u',
      identifierHash: hash,
    );

    test('without a hash the key is the earlier format', () {
      expect(key(), 'https://a|||u|||in');
      expect(key(hash: ''), key());
    });

    test('same identifier, different hash: different key', () {
      expect(key(hash: 'h1'), isNot(key(hash: 'h2')));
      expect(key(hash: 'h1'), isNot(key()));
      expect(key(hash: 'h1'), key(hash: 'h1'));
    });

    test('the raw hash is not part of the key', () {
      expect(key(hash: 'my-secret-hash'), isNot(contains('my-secret-hash')));
    });
  });

  group('zukkoChatInstanceKey', () {
    String key({String? user}) => zukkoChatInstanceKey(
      baseUrl: 'https://a',
      websiteToken: 'in',
      userIdentifier: user,
    );

    // P10: null was interpolated as "null" and collided with a real "null" user
    test('no user differs from a user called "null"', () {
      expect(key(user: null), isNot(key(user: 'null')));
    });

    test('a separator inside a component cannot forge another key', () {
      final forged = zukkoChatInstanceKey(
        baseUrl: 'https://a',
        websiteToken: 'in',
        userIdentifier: 'x|||y',
      );
      final other = zukkoChatInstanceKey(
        baseUrl: 'https://a|||x',
        websiteToken: 'in',
        userIdentifier: 'y',
      );

      expect(forged, isNot(other));
    });

    test('is stable for plain values', () {
      expect(key(user: 'u'), 'https://a|||u|||in');
    });
  });
}
