import 'package:hive_ce/hive.dart';

import '../../core/chatwoot_client_exception.dart';
import '../models/chatwoot_contact.dart';
import '../models/chatwoot_conversation.dart';
import '../models/chatwoot_event_message_user.dart';
import '../models/chatwoot_message.dart';
import '../models/chatwoot_user.dart';
import 'hive_type_ids.dart';

final _registered = <int>{};

/// Registers every Hive adapter the SDK needs. Safe to call repeatedly.
///
/// Throws a [ChatwootClientException] of type `STORAGE_FAILED` when the host
/// app already registered a different adapter on one of the SDK's type ids:
/// skipping ours would make Hive read the SDK's records with a foreign adapter.
void registerChatwootAdapters() {
  void register<T>(int typeId, TypeAdapter<T> Function() adapter) {
    if (_registered.contains(typeId)) return;
    try {
      Hive.registerAdapter(adapter());
    } on HiveError catch (e) {
      throw ChatwootClientException(
        'Hive typeId $typeId is already used by another adapter of the host '
        'app; the SDK needs ids 0-4 (${e.message})',
        ChatwootClientExceptionType.STORAGE_FAILED,
      );
    }
    _registered.add(typeId);
  }

  register(chatwootContactHiveTypeId, ChatwootContactAdapter.new);
  register(chatwootConversationHiveTypeId, ChatwootConversationAdapter.new);
  register(chatwootMessageHiveTypeId, ChatwootMessageAdapter.new);
  register(chatwootUserHiveTypeId, ChatwootUserAdapter.new);
  register(chatwootEventUserHiveTypeId, ChatwootEventMessageUserAdapter.new);
}
