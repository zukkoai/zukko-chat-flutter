import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:synchronized/synchronized.dart';

import '../../core/chatwoot_client_exception.dart';
import '../../shared/sdk_log.dart';

import '../models/chatwoot_contact.dart';
import '../models/chatwoot_conversation.dart';
import '../models/chatwoot_message.dart';
import '../models/chatwoot_user.dart';
import 'dao/chatwoot_messages_dao.dart';
import 'dao/single_store.dart';
import 'hive_adapters.dart';
import 'key_store.dart';
import 'instance_key.dart';

/// Hive box names. They are the file names on users' devices, so the values are
/// pinned as literals: renaming one would orphan persisted data.
abstract final class ChatwootBoxNames {
  // Encrypted boxes (SDK >= 0.0.10).
  static const contacts = 'ChatwootContactBoxNames.CONTACTS.enc';
  static const conversations = 'ChatwootConversationBoxNames.CONVERSATIONS.enc';
  static const messages = 'ChatwootMessagesBoxNames.MESSAGES.enc';
  static const users = 'ChatwootUserBoxNames.USERS.enc';

  // Plaintext boxes of earlier SDK versions. Their records are moved into the
  // encrypted boxes by `LocalStorage.openDB`, then the boxes are deleted.
  static const legacyContacts = 'ChatwootContactBoxNames.CONTACTS';
  static const legacyConversations =
      'ChatwootConversationBoxNames.CONVERSATIONS';
  static const legacyMessages = 'ChatwootMessagesBoxNames.MESSAGES';
  static const legacyUsers = 'ChatwootUserBoxNames.USERS';

  // Index boxes of SDK <= 0.0.9 (`instanceKey -> entity id`).
  static const legacyContactIndex =
      'ChatwootContactBoxNames.CLIENT_INSTANCE_TO_CONTACTS';
  static const legacyConversationIndex =
      'ChatwootConversationBoxNames.CLIENT_INSTANCE_TO_CONVERSATIONS';
  static const legacyMessageIndex =
      'ChatwootMessagesBoxNames.MESSAGES_TO_CLIENT_INSTANCE_KEY';
  static const legacyUserIndex = 'ChatwootUserBoxNames.CLIENT_INSTANCE_TO_USER';

  static const _allLegacy = [
    legacyContacts,
    legacyConversations,
    legacyMessages,
    legacyUsers,
    legacyContactIndex,
    legacyConversationIndex,
    legacyMessageIndex,
    legacyUserIndex,
  ];
}

/// Storage of one client instance: its contact, conversation, user and messages.
///
/// Persisted storage keeps the Hive boxes open for the lifetime of the process
/// (boxes are shared by every client instance); [dispose] only releases
/// per-instance in-memory state.
class LocalStorage {
  LocalStorage({
    required this.contact,
    required this.conversation,
    required this.user,
    required this.messages,
  });

  /// Hive-backed storage for [instanceKey]. [openDB] must have completed.
  factory LocalStorage.persisted(String instanceKey) => LocalStorage(
    contact: HiveSingleStore(
      Hive.box<ZukkoChatContact>(ChatwootBoxNames.contacts),
      instanceKey,
    ),
    conversation: HiveSingleStore(
      Hive.box<ZukkoChatConversation>(ChatwootBoxNames.conversations),
      instanceKey,
    ),
    user: HiveUserStore(
      Hive.box<ZukkoChatUser>(ChatwootBoxNames.users),
      instanceKey,
    ),
    messages: PersistedChatwootMessagesDao(
      Hive.box<ZukkoChatMessage>(ChatwootBoxNames.messages),
      instanceKey,
    ),
  );

  /// Plain in-memory storage, private to the owning client.
  factory LocalStorage.inMemory() => LocalStorage(
    contact: MemorySingleStore(),
    conversation: MemorySingleStore(),
    user: MemorySingleStore(),
    messages: InMemoryChatwootMessagesDao(),
  );

  final SingleStore<ZukkoChatContact> contact;
  final SingleStore<ZukkoChatConversation> conversation;
  final SingleStore<ZukkoChatUser> user;
  final ChatwootMessagesDao messages;

  /// Where the boxes' encryption key is kept. Tests replace it with a fake.
  @visibleForTesting
  static ChatwootKeyStore keyStore = SecureChatwootKeyStore();

  static final _openLock = Lock();

  /// Initialises Hive, registers adapters, opens the encrypted SDK boxes and
  /// moves records of earlier plaintext layouts into them. Idempotent and
  /// serialised: concurrent calls run one after the other.
  ///
  /// Throws a [ZukkoChatException] (`STORAGE_FAILED`) when a foreign Hive
  /// adapter occupies one of the SDK's type ids.
  static Future<void> openDB() => _openLock.synchronized(() async {
    await Hive.initFlutter();
    registerChatwootAdapters();
    final cipher = HiveAesCipher(await _encryptionKey());

    final contacts = await _openEncrypted<ZukkoChatContact>(
      ChatwootBoxNames.contacts,
      cipher,
    );
    final conversations = await _openEncrypted<ZukkoChatConversation>(
      ChatwootBoxNames.conversations,
      cipher,
    );
    final messages = await _openEncrypted<ZukkoChatMessage>(
      ChatwootBoxNames.messages,
      cipher,
    );
    final users = await _openEncrypted<ZukkoChatUser>(
      ChatwootBoxNames.users,
      cipher,
    );

    await _migrateLegacy(contacts, conversations, messages, users);
  });

  /// The 256-bit box key; generated and stored on first use.
  static Future<List<int>> _encryptionKey() async {
    final stored = await keyStore.read();
    if (stored != null && stored.length == 32) return stored;
    final fresh = Hive.generateSecureKey();
    await keyStore.write(fresh);
    return fresh;
  }

  /// Opens an encrypted box. When the key no longer fits (keystore reset,
  /// restored backup) the box is unreadable; its content is only a cache of
  /// server state, so it is recreated instead of failing every start.
  static Future<Box<T>> _openEncrypted<T>(
    String name,
    HiveCipher cipher,
  ) async {
    try {
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    } on HiveError catch (e) {
      sdkLog('box $name is unreadable, recreating it: ${e.message}');
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<T>(name, encryptionCipher: cipher);
    }
  }

  /// Deletes every persisted SDK record of every client instance, including
  /// leftovers of earlier plaintext layouts.
  static Future<void> clearAllPersisted() async {
    await openDB();
    await Hive.box<ZukkoChatContact>(ChatwootBoxNames.contacts).clear();
    await Hive.box<ZukkoChatConversation>(ChatwootBoxNames.conversations)
        .clear();
    await Hive.box<ZukkoChatMessage>(ChatwootBoxNames.messages).clear();
    await Hive.box<ZukkoChatUser>(ChatwootBoxNames.users).clear();
    for (final legacy in ChatwootBoxNames._allLegacy) {
      await Hive.deleteBoxFromDisk(legacy);
    }
  }

  /// Deletes every record of the instance with key [baseKey] (a key made
  /// WITHOUT an identifier hash) and of its hash variants (`baseKey|||h:<digest>`),
  /// including their messages (`<key>|m|<id>`). Other instances are untouched:
  /// a component is escaped, so no other key can start with [baseKey] followed
  /// by one of those separators.
  static Future<void> clearInstanceFamily(String baseKey) async {
    await openDB();
    bool mine(Object? key) =>
        key is String &&
        (key == baseKey ||
            key.startsWith('$baseKey|m|') ||
            key.startsWith('$baseKey|||h:'));
    Future<void> sweep<T>(String name) async {
      final box = Hive.box<T>(name);
      await box.deleteAll(box.keys.where(mine).toList());
    }

    await sweep<ZukkoChatContact>(ChatwootBoxNames.contacts);
    await sweep<ZukkoChatConversation>(ChatwootBoxNames.conversations);
    await sweep<ZukkoChatMessage>(ChatwootBoxNames.messages);
    await sweep<ZukkoChatUser>(ChatwootBoxNames.users);
  }

  /// Deletes this instance's data. Contact and user are kept unless
  /// [clearChatwootUserStorage] is true.
  Future<void> clear({bool clearChatwootUserStorage = true}) async {
    await conversation.delete();
    await messages.clear();
    if (clearChatwootUserStorage) {
      await user.delete();
      await contact.delete();
    }
  }

  /// Releases in-memory state. Persisted data and open boxes are untouched.
  Future<void> dispose() async {
    if (contact is MemorySingleStore) await contact.delete();
    if (conversation is MemorySingleStore) await conversation.delete();
    if (user is MemorySingleStore) await user.delete();
    if (messages is InMemoryChatwootMessagesDao) await messages.clear();
  }

  // ---- migration of plaintext boxes of earlier SDK versions ----
  //
  // Two layouts exist: <= 0.0.9 (entity-id keys + index boxes mapping the
  // instance key to the entity) and the unreleased instance-keyed one. Every
  // record is first written to the encrypted box and only then deleted from
  // the plaintext one; a record that cannot be attributed to an instance (an
  // unparseable legacy key) stays where it is, untouched, and so do the
  // boxes holding it.

  static Future<void> _migrateLegacy(
    Box<ZukkoChatContact> contacts,
    Box<ZukkoChatConversation> conversations,
    Box<ZukkoChatMessage> messages,
    Box<ZukkoChatUser> users,
  ) async {
    await _migrate<ZukkoChatContact>(
      ChatwootBoxNames.legacyContacts,
      ChatwootBoxNames.legacyContactIndex,
      contacts,
      (index) => [
        for (final e in index.entries)
          (indexKey: e.key, oldKey: e.value, newKey: _newKey(e.key)),
      ],
    );
    await _migrate<ZukkoChatConversation>(
      ChatwootBoxNames.legacyConversations,
      ChatwootBoxNames.legacyConversationIndex,
      conversations,
      (index) => [
        for (final e in index.entries)
          (
            indexKey: e.key,
            oldKey: int.tryParse(e.value),
            newKey: _newKey(e.key),
          ),
      ],
    );
    await _migrate<ZukkoChatUser>(
      ChatwootBoxNames.legacyUsers,
      ChatwootBoxNames.legacyUserIndex,
      users,
      (index) => [
        for (final e in index.entries)
          (indexKey: e.key, oldKey: e.value, newKey: _newKey(e.key)),
      ],
      sanitize: (u) => u.toPersistable(),
    );
    await _migrate<ZukkoChatMessage>(
      ChatwootBoxNames.legacyMessages,
      ChatwootBoxNames.legacyMessageIndex,
      messages,
      (index) => [
        for (final e in index.entries)
          (
            indexKey: e.key,
            oldKey: e.key, // the index is keyed by the message id
            newKey: switch (_newKey(e.value)) {
              final instance? => '$instance|m|${e.key}',
              _ => null,
            },
          ),
      ],
    );
  }

  static String? _newKey(Object? legacyInstanceKey) =>
      legacyInstanceKey is String
      ? chatwootInstanceKeyFromLegacy(legacyInstanceKey)
      : null;

  /// Moves one legacy box into [target]: `oldKey -> newKey` for every entry
  /// the index resolves, and instance-keyed entries as they are.
  static Future<void> _migrate<T>(
    String boxName,
    String indexName,
    Box<T> target,
    List<({Object indexKey, Object? oldKey, String? newKey})> Function(
      Map<Object, String> index,
    )
    plan, {
    T Function(T)? sanitize,
  }) async {
    final hasBox = await Hive.boxExists(boxName);
    final hasIndex = await Hive.boxExists(indexName);
    if (!hasBox && !hasIndex) return;

    final index = hasIndex ? await Hive.openBox<String>(indexName) : null;
    final legacy = hasBox ? await Hive.openBox<T>(boxName) : null;
    T clean(T v) => sanitize == null ? v : sanitize(v);

    final movedEntities = <Object>{};
    final keptEntities = <Object>{};
    final doneIndexKeys = <Object>[];
    if (index != null) {
      final entries = {
        for (final e in index.toMap().entries) e.key as Object: e.value,
      };
      for (final step in plan(entries)) {
        final value = step.oldKey == null ? null : legacy?.get(step.oldKey);
        if (step.oldKey != null && value == null) {
          doneIndexKeys.add(step.indexKey); // dangling: nothing to migrate
        } else if (step.newKey == null || step.oldKey == null) {
          if (step.oldKey != null) keptEntities.add(step.oldKey!);
        } else {
          if (!target.containsKey(step.newKey)) {
            await target.put(step.newKey!, clean(value as T));
          }
          movedEntities.add(step.oldKey!);
          doneIndexKeys.add(step.indexKey);
        }
      }
    }
    if (legacy != null) {
      // entries already keyed by instance (unreleased layout)
      for (final key in legacy.keys.toList()) {
        if (key is String && isInstanceKey(key)) {
          if (!target.containsKey(key)) {
            await target.put(key, clean(legacy.get(key) as T));
          }
          movedEntities.add(key);
        }
      }
      await legacy.deleteAll(movedEntities.difference(keptEntities));
    }
    await index?.deleteAll(doneIndexKeys);

    for (final box in <Box<dynamic>?>[legacy, index]) {
      if (box == null) continue;
      if (box.isEmpty) {
        await box.deleteFromDisk();
      } else {
        await box.close();
      }
    }
  }
}
