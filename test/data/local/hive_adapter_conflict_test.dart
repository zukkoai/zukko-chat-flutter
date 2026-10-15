import 'package:zukko_chat_flutter/src/core/chatwoot_client_exception.dart';
import 'package:zukko_chat_flutter/src/data/local/hive_type_ids.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../utils/hive_test_env.dart';

class _Foreign {}

class _ForeignAdapter extends TypeAdapter<_Foreign> {
  @override
  int get typeId => chatwootContactHiveTypeId;

  @override
  _Foreign read(BinaryReader reader) => _Foreign();

  @override
  void write(BinaryWriter writer, _Foreign obj) {}
}

/// Own file on purpose: adapter registration is process-wide, so this must run
/// before anything registered the SDK's adapters.
void main() {
  final env = HiveTestEnv();
  setUpAll(env.setUpAll);
  tearDownAll(env.tearDownAll);

  // F8
  test('a foreign adapter on an SDK type id makes openDB throw a typed '
      'error that names the id', () async {
    Hive.registerAdapter(_ForeignAdapter());

    await expectLater(
      LocalStorage.openDB(),
      throwsA(
        isA<ZukkoChatException>()
            .having(
              (e) => e.type,
              'type',
              ZukkoChatExceptionType.STORAGE_FAILED,
            )
            .having((e) => e.cause, 'cause', contains('typeId 0')),
      ),
    );
  });
}
