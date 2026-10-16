import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:synchronized/synchronized.dart';

import '../../shared/sdk_log.dart';
import '../models/zukko_chat_contact.dart';
import '../models/zukko_chat_conversation.dart';
import '../models/zukko_chat_message.dart';
import 'hive_adapters.dart';
import 'key_store.dart';
import 'zukko_chat_box_names.dart';

/// The process-wide Hive side of local storage: bootstrap (init, adapters,
/// cipher, boxes) and the wipes that span all client instances. The boxes are
/// shared by every client and stay open for the lifetime of the process.
abstract final class HiveDatabase {
  /// Where the boxes' encryption key is kept. Tests replace it with a fake.
  @visibleForTesting
  static ZukkoChatKeyStore keyStore = SecureZukkoChatKeyStore();

  static final _openLock = Lock();
  static final _recreated = <String>[];

  /// The SDK's open boxes. [openDB] must have completed.
  static List<Box<Object?>> get _boxes => [
    Hive.box<ZukkoChatContact>(ZukkoChatBoxNames.contacts),
    Hive.box<ZukkoChatConversation>(ZukkoChatBoxNames.conversations),
    Hive.box<ZukkoChatMessage>(ZukkoChatBoxNames.messages),
  ];

  /// Names of boxes that were unreadable and recreated empty since the last
  /// call (the visitor lost their session); each is reported once.
  static List<String> takeRecreated() {
    final names = List.of(_recreated);
    _recreated.clear();
    return names;
  }

  /// Initialises Hive, registers adapters and opens the encrypted SDK boxes.
  /// Idempotent and serialised: concurrent calls run one after the other.
  ///
  /// Throws a `ZukkoChatException` (`STORAGE_FAILED`) when a foreign Hive
  /// adapter occupies one of the SDK's type ids.
  static Future<void> openDB() => _openLock.synchronized(() async {
    await Hive.initFlutter();
    registerZukkoChatAdapters();
    final cipher = HiveAesCipher(await _encryptionKey());
    await _openEncrypted<ZukkoChatContact>(ZukkoChatBoxNames.contacts, cipher);
    await _openEncrypted<ZukkoChatConversation>(
      ZukkoChatBoxNames.conversations,
      cipher,
    );
    await _openEncrypted<ZukkoChatMessage>(ZukkoChatBoxNames.messages, cipher);
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
    } catch (e) {
      // wrong/lost key, restored files, unknown (old) type ids: any failure
      // to read the box means its cache is unusable
      sdkLog(
        'box $name is unreadable, recreating it: ${e.runtimeType}',
        level: SdkLogLevel.warning,
      );
      _recreated.add(name);
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<T>(name, encryptionCipher: cipher);
    }
  }

  /// Deletes every persisted SDK record of every client instance (and the
  /// retired users box).
  static Future<void> clearAll() async {
    await openDB();
    for (final box in _boxes) {
      await box.clear();
    }
    await Hive.deleteBoxFromDisk(ZukkoChatBoxNames.users);
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
    for (final box in _boxes) {
      await box.deleteAll(box.keys.where(mine).toList());
      await box.compact();
    }
  }
}
