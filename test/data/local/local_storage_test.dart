import 'dart:convert';
import 'dart:io';

import 'package:zukko_chat_flutter/src/data/local/hive_adapters.dart';
import 'package:zukko_chat_flutter/src/data/local/instance_key.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:zukko_chat_flutter/src/data/models/chatwoot_contact.dart';
import 'package:zukko_chat_flutter/src/data/models/chatwoot_conversation.dart';
import 'package:zukko_chat_flutter/src/data/models/chatwoot_message.dart';
import 'package:zukko_chat_flutter/src/data/models/chatwoot_user.dart';
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

      test('contact, conversation and user round-trip and delete', () async {
        final storage = make('k');
        expect(storage.contact.get(), isNull);

        await storage.contact.save(contact());
        await storage.conversation.save(conversation());
        await storage.user.save(user());

        expect(storage.contact.get(), contact());
        expect(storage.conversation.get()!.id, 7);
        expect(storage.user.get(), user());

        await storage.contact.delete();
        expect(storage.contact.get(), isNull);
      });

      test('saving again overwrites', () async {
        final storage = make('k');
        await storage.conversation.save(conversation(id: 1));
        await storage.conversation.save(conversation(id: 2));

        expect(storage.conversation.get()!.id, 2);
      });

      // P10: user without identifier used to be stored under "null"/box.put(null)
      test('a user without identifier can be saved and read back', () async {
        final storage = make('k');
        final anonymous = ZukkoChatUser(name: 'only a name');

        await storage.user.save(anonymous);

        expect(storage.user.get(), anonymous);
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

      test('clear() keeps contact and user unless asked', () async {
        final storage = make('k');
        await storage.contact.save(contact());
        await storage.user.save(user());
        await storage.conversation.save(conversation());
        await storage.messages.saveMessage(message(1));

        await storage.clear(clearChatwootUserStorage: false);

        expect(storage.conversation.get(), isNull);
        expect(storage.messages.getMessages(), isEmpty);
        expect(storage.contact.get(), isNotNull);
        expect(storage.user.get(), isNotNull);

        await storage.clear();

        expect(storage.contact.get(), isNull);
        expect(storage.user.get(), isNull);
      });
    });
  }

  group('persisted storage specifics', () {
    setUp(env.open);

    test('data survives closing and reopening the boxes', () async {
      final key = chatwootInstanceKey(
        baseUrl: 'https://a',
        websiteToken: 'in',
        userIdentifier: 'u',
      );
      await LocalStorage.persisted(key).contact.save(contact());
      await LocalStorage.persisted(key).messages.saveMessage(message(1));

      await Hive.close();
      await LocalStorage.openDB();

      final storage = LocalStorage.persisted(key);
      expect(storage.contact.get(), contact());
      expect(storage.messages.getMessages(), hasLength(1));
    });

    test('openDB is idempotent', () async {
      await LocalStorage.persisted('k').contact.save(contact());

      await LocalStorage.openDB();
      await LocalStorage.openDB();

      expect(LocalStorage.persisted('k').contact.get(), isNotNull);
    });

    // An instance key that is a prefix of another must not see its messages.
    test('instance keys that are prefixes do not leak messages', () async {
      final short = LocalStorage.persisted(
        chatwootInstanceKey(
          baseUrl: 'https://a',
          websiteToken: 'in',
          userIdentifier: 'u',
        ),
      );
      final long = LocalStorage.persisted(
        chatwootInstanceKey(
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

      await LocalStorage.clearAllPersisted();

      expect(LocalStorage.persisted('a').contact.get(), isNull);
      expect(LocalStorage.persisted('b').messages.getMessages(), isEmpty);
    });

    test('box names are pinned to the names of earlier SDK versions', () {
      expect(
        ChatwootBoxNames.legacyContacts,
        'ChatwootContactBoxNames.CONTACTS',
      );
      expect(
        ChatwootBoxNames.legacyConversations,
        'ChatwootConversationBoxNames.CONVERSATIONS',
      );
      expect(
        ChatwootBoxNames.legacyMessages,
        'ChatwootMessagesBoxNames.MESSAGES',
      );
      expect(ChatwootBoxNames.legacyUsers, 'ChatwootUserBoxNames.USERS');
      // the encrypted boxes are new files next to them, never the same ones
      expect(ChatwootBoxNames.contacts, isNot(ChatwootBoxNames.legacyContacts));
    });
  });

  group('migration of the plaintext layouts', () {
    const legacyKey = 'https://old.example|||null|||inbox-1';
    final newKey = chatwootInstanceKey(
      baseUrl: 'https://old.example',
      websiteToken: 'inbox-1',
    );

    Future<Box<T>> legacy<T>(String name) => Hive.openBox<T>(name);

    /// Writes the data the way SDK <= 0.0.9 did: plaintext, entity-id keys +
    /// index boxes.
    Future<void> seedLegacy({String indexKey = legacyKey}) async {
      await (await legacy<ZukkoChatContact>(ChatwootBoxNames.legacyContacts))
          .put('source-1', contact());
      await (await legacy<String>(ChatwootBoxNames.legacyContactIndex))
          .put(indexKey, 'source-1');
      await (await legacy<ZukkoChatConversation>(
        ChatwootBoxNames.legacyConversations,
      )).put(7, conversation());
      await (await legacy<String>(ChatwootBoxNames.legacyConversationIndex))
          .put(indexKey, '7');
      await (await legacy<ZukkoChatUser>(ChatwootBoxNames.legacyUsers))
          .put('user-1', user());
      await (await legacy<String>(ChatwootBoxNames.legacyUserIndex))
          .put(indexKey, 'user-1');
      await (await legacy<ZukkoChatMessage>(ChatwootBoxNames.legacyMessages))
          .put(8, message(8));
      await (await legacy<String>(ChatwootBoxNames.legacyMessageIndex))
          .put(8, indexKey);
    }

    setUp(() async {
      registerChatwootAdapters();
      Hive.init(env.dir.path);
    });

    test('moves contact, conversation, user and messages to encrypted '
        'instance-keyed boxes and deletes the plaintext ones', () async {
      await seedLegacy();

      await LocalStorage.openDB(); // migrates

      final storage = LocalStorage.persisted(newKey);
      expect(storage.contact.get(), contact());
      expect(storage.conversation.get()!.id, 7);
      expect(storage.user.get(), user());
      expect(storage.messages.getMessages().map((m) => m.id), [8]);
      expect(Hive.box<ZukkoChatContact>(ChatwootBoxNames.contacts).keys, [
        newKey,
      ]);
      expect(Hive.box<ZukkoChatMessage>(ChatwootBoxNames.messages).keys, [
        '$newKey|m|8',
      ]);
      for (final name in [
        ChatwootBoxNames.legacyContacts,
        ChatwootBoxNames.legacyConversations,
        ChatwootBoxNames.legacyUsers,
        ChatwootBoxNames.legacyMessages,
        ChatwootBoxNames.legacyContactIndex,
        ChatwootBoxNames.legacyConversationIndex,
        ChatwootBoxNames.legacyUserIndex,
        ChatwootBoxNames.legacyMessageIndex,
      ]) {
        expect(await Hive.boxExists(name), false, reason: name);
      }
    });

    // F2
    test('an index entry with an unparseable key is NOT deleted: value and '
        'index stay, the resolvable ones still move', () async {
      await seedLegacy();
      // a second contact whose index key cannot be parsed (4 parts)
      await Hive.box<ZukkoChatContact>(ChatwootBoxNames.legacyContacts)
          .put('source-2', contact(id: 2, identifier: 'source-2'));
      await Hive.box<String>(ChatwootBoxNames.legacyContactIndex)
          .put('a|||b|||c|||d', 'source-2');
      await Hive.box<ZukkoChatMessage>(ChatwootBoxNames.legacyMessages)
          .put(9, message(9));
      await Hive.box<String>(ChatwootBoxNames.legacyMessageIndex)
          .put(9, 'a|||b|||c|||d');

      await LocalStorage.openDB();

      expect(LocalStorage.persisted(newKey).contact.get(), contact());
      expect(
        LocalStorage.persisted(newKey).messages.getMessages(),
        hasLength(1),
      );
      final keptContacts = await Hive.openBox<ZukkoChatContact>(
        ChatwootBoxNames.legacyContacts,
      );
      expect(keptContacts.keys, ['source-2']);
      expect(
        (await Hive.openBox<String>(ChatwootBoxNames.legacyContactIndex))
            .toMap(),
        {'a|||b|||c|||d': 'source-2'},
      );
      expect(
        (await Hive.openBox<ZukkoChatMessage>(ChatwootBoxNames.legacyMessages))
            .keys,
        [9],
      );
      // the resolved index boxes are gone
      expect(await Hive.boxExists(ChatwootBoxNames.legacyUserIndex), false);
    });

    test('running it again does not overwrite newer encrypted data with '
        'stale legacy data', () async {
      await seedLegacy(indexKey: legacyKey);
      await Hive.box<ZukkoChatContact>(ChatwootBoxNames.legacyContacts)
          .put('source-2', contact(id: 2));
      await Hive.box<String>(ChatwootBoxNames.legacyContactIndex)
          .put('a|||b|||c|||d', 'source-2'); // keeps the legacy boxes alive
      await LocalStorage.openDB();
      await LocalStorage.persisted(newKey).contact
          .save(contact(pubsubToken: 'newer'));

      await LocalStorage.openDB();

      expect(
        LocalStorage.persisted(newKey).contact.get()!.pubsubToken,
        'newer',
      );
    });

    test(
      'a legacy user is migrated without identifierHash and attributes',
      () async {
        await seedLegacy();
        await Hive.box<ZukkoChatUser>(ChatwootBoxNames.legacyUsers).put(
          'user-1',
          ZukkoChatUser(
            identifier: 'user-1',
            identifierHash: 'secret-hash',
            customAttributes: {'plan': 'gold'},
          ),
        );

        await LocalStorage.openDB();

        final migrated = Hive.box<ZukkoChatUser>(ChatwootBoxNames.users)
            .get(newKey)!;
        expect(migrated.identifier, 'user-1');
        expect(migrated.identifierHash, isNull);
        expect(migrated.customAttributes, isNull);
      },
    );

    test(
      'entries already keyed by instance (unreleased layout) move too',
      () async {
        await (await legacy<ZukkoChatContact>(ChatwootBoxNames.legacyContacts))
            .put(newKey, contact());

        await LocalStorage.openDB();

        expect(LocalStorage.persisted(newKey).contact.get(), contact());
        expect(await Hive.boxExists(ChatwootBoxNames.legacyContacts), false);
      },
    );
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
        Hive.box<ZukkoChatContact>(ChatwootBoxNames.contacts),
      );
      final messageBytes = await bytesOf(
        Hive.box<ZukkoChatMessage>(ChatwootBoxNames.messages),
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
      await LocalStorage.openDB();

      expect(env.keys.key, key);
      expect(env.keys.writes, 1);
    });

    test('data is readable after a restart with the same key', () async {
      await LocalStorage.persisted('k').contact
          .save(contact(authToken: 'jwt-1'));

      await Hive.close();
      await LocalStorage.openDB();

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

        await LocalStorage.openDB();

        expect(LocalStorage.persisted('k').contact.get(), isNull);
        await LocalStorage.persisted('k').contact.save(contact());
        expect(LocalStorage.persisted('k').contact.get(), isNotNull);
      },
    );

    test('identifierHash and customAttributes never reach the disk', () async {
      final full = ZukkoChatUser(
        identifier: 'u',
        identifierHash: 'HASH-SECRET',
        customAttributes: {'plan': 'gold'},
        email: 'a@b.c',
      );
      final storage = LocalStorage.persisted('k');

      await storage.user.save(full);

      // this process still has the full user (contact creation needs it) ...
      expect(storage.user.get(), full);
      // ... a fresh store (another process) reads what is on disk
      final onDisk = LocalStorage.persisted('k').user.get()!;
      expect(onDisk.identifier, 'u');
      expect(onDisk.email, 'a@b.c');
      expect(onDisk.identifierHash, isNull);
      expect(onDisk.customAttributes, isNull);
      await storage.user.delete();
      expect(storage.user.get(), isNull);
    });
  });

  // F9
  group('openDB is serialised', () {
    test(
      'concurrent calls with legacy boxes migrate once, no exception',
      () async {
        registerChatwootAdapters();
        Hive.init(env.dir.path);
        await (await Hive.openBox<ZukkoChatContact>(
          ChatwootBoxNames.legacyContacts,
        )).put('source-1', contact());
        await (await Hive.openBox<String>(ChatwootBoxNames.legacyContactIndex))
            .put('https://a|||null|||in', 'source-1');
        await Hive.close();

        await Future.wait([
          LocalStorage.openDB(),
          LocalStorage.openDB(),
          LocalStorage.openDB(),
        ]);

        final key = chatwootInstanceKey(
          baseUrl: 'https://a',
          websiteToken: 'in',
        );
        expect(LocalStorage.persisted(key).contact.get(), contact());
        expect(env.keys.writes, 1);
      },
    );
  });

  group('chatwootInstanceKey hash (SEC5)', () {
    String key({String? hash}) => chatwootInstanceKey(
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

  group('chatwootInstanceKey', () {
    String key({String? user}) => chatwootInstanceKey(
      baseUrl: 'https://a',
      websiteToken: 'in',
      userIdentifier: user,
    );

    // P10: null was interpolated as "null" and collided with a real "null" user
    test('no user differs from a user called "null"', () {
      expect(key(user: null), isNot(key(user: 'null')));
    });

    test('a separator inside a component cannot forge another key', () {
      final forged = chatwootInstanceKey(
        baseUrl: 'https://a',
        websiteToken: 'in',
        userIdentifier: 'x|||y',
      );
      final other = chatwootInstanceKey(
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
