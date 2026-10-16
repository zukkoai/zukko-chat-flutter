import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/core/zukko_chat_client_exception.dart';
import 'package:zukko_chat_flutter/src/data/local/hive_database.dart';
import 'package:zukko_chat_flutter/src/data/local/open_storage.dart';
import 'package:zukko_chat_flutter/src/data/local/key_store.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:hive_ce/hive.dart';

import '../../utils/fixtures.dart';
import '../../utils/hive_test_env.dart';

class _BrokenKeyStore implements ZukkoChatKeyStore {
  @override
  Future<List<int>?> read() => throw StateError('keystore unavailable');

  @override
  Future<void> write(List<int> key) => throw StateError('keystore unavailable');
}

void main() {
  final env = HiveTestEnv();
  setUpAll(env.setUpAll);
  tearDown(env.tearDown);
  tearDownAll(env.tearDownAll);

  test('without persistence it is in memory and silent', () async {
    final errors = <ZukkoChatException>[];

    final storage = await openStorage(
      persist: false,
      instanceKey: 'k',
      onError: errors.add,
    );
    await storage.contact.save(contact());

    expect(errors, isEmpty);
    expect(Hive.isBoxOpen('ChatwootContactBoxNames.CONTACTS.enc'), isFalse);
  });

  test('a broken keystore falls back to memory and reports once', () async {
    final saved = HiveDatabase.keyStore;
    HiveDatabase.keyStore = _BrokenKeyStore();
    addTearDown(() => HiveDatabase.keyStore = saved);
    final errors = <ZukkoChatException>[];

    final storage = await openStorage(
      persist: true,
      instanceKey: 'k',
      onError: errors.add,
    );
    await storage.contact.save(contact());

    expect(errors.map((e) => e.type), [ZukkoChatExceptionType.STORAGE_FAILED]);
    expect(storage.contact.get(), contact());
  });

  // R11: a lost key used to wipe the visitor's session without a word
  test('an unreadable box that was recreated is reported', () async {
    await HiveDatabase.openDB();
    await LocalStorage.persisted('k').contact.save(contact());
    await Hive.close();
    env.keys.key = null; // keystore was reset
    final errors = <ZukkoChatException>[];

    await openStorage(persist: true, instanceKey: 'k', onError: errors.add);

    expect(errors.map((e) => e.type), [ZukkoChatExceptionType.STORAGE_FAILED]);
    expect(errors.single.cause, contains('reset'));
  });
}
