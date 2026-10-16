import 'package:hive_ce/hive.dart';

import '../../core/zukko_chat_client_exception.dart';
import '../models/zukko_chat_contact.dart';
import '../models/zukko_chat_conversation.dart';
import '../models/zukko_chat_event_message_user.dart';
import '../models/zukko_chat_message.dart';
import '../models/zukko_chat_user.dart';
import 'hive_type_ids.dart';

final _registered = <int>{};

/// Registers every Hive adapter the SDK needs. Safe to call repeatedly.
///
/// Throws a [ZukkoChatException] of type `STORAGE_FAILED` when the host
/// app already registered a different adapter on one of the SDK's type ids:
/// skipping ours would make Hive read the SDK's records with a foreign adapter.
void registerZukkoChatAdapters() {
  void register<T>(int typeId, TypeAdapter<T> Function() adapter) {
    if (_registered.contains(typeId)) return;
    try {
      Hive.registerAdapter(adapter());
    } on HiveError catch (e) {
      throw ZukkoChatException(
        'Hive typeId $typeId is already used by another adapter of the host '
        'app; the SDK needs ids 210-214 (${e.message})',
        ZukkoChatExceptionType.storageFailed,
      );
    }
    _registered.add(typeId);
  }

  register(zukkoChatContactHiveTypeId, ZukkoChatContactAdapter.new);
  register(zukkoChatConversationHiveTypeId, ZukkoChatConversationAdapter.new);
  register(zukkoChatMessageHiveTypeId, ZukkoChatMessageAdapter.new);
  register(zukkoChatUserHiveTypeId, ZukkoChatUserAdapter.new);
  register(zukkoChatEventUserHiveTypeId, ZukkoChatEventMessageUserAdapter.new);
}
