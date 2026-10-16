import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/zukko_chat_contact.dart';
import '../models/zukko_chat_conversation.dart';
import '../models/zukko_chat_message.dart';
import 'dao/single_store.dart';
import 'dao/zukko_chat_messages_dao.dart';
import 'zukko_chat_box_names.dart';

/// Storage of one client instance: its contact, conversation and messages,
/// either in the shared Hive boxes ([persisted]) or in memory ([inMemory]).
/// Nothing needs releasing: persisted data stays, in-memory data is garbage
/// collected with the client.
class LocalStorage {
  LocalStorage({
    required this.contact,
    required this.conversation,
    required this.messages,
  });

  /// Hive-backed storage for [instanceKey]. `HiveDatabase.openDB` must have
  /// completed.
  factory LocalStorage.persisted(String instanceKey) => LocalStorage(
    contact: HiveSingleStore(
      Hive.box<ZukkoChatContact>(ZukkoChatBoxNames.contacts),
      instanceKey,
    ),
    conversation: HiveSingleStore(
      Hive.box<ZukkoChatConversation>(ZukkoChatBoxNames.conversations),
      instanceKey,
    ),
    messages: PersistedZukkoChatMessagesDao(
      Hive.box<ZukkoChatMessage>(ZukkoChatBoxNames.messages),
      instanceKey,
    ),
  );

  /// Plain in-memory storage, private to the owning client.
  factory LocalStorage.inMemory() => LocalStorage(
    contact: MemorySingleStore(),
    conversation: MemorySingleStore(),
    messages: InMemoryZukkoChatMessagesDao(),
  );

  final SingleStore<ZukkoChatContact> contact;
  final SingleStore<ZukkoChatConversation> conversation;
  final ZukkoChatMessagesDao messages;

  /// Deletes this instance's conversation and messages, and the contact too
  /// when [clearContact] is true.
  Future<void> clear({bool clearContact = true}) async {
    await conversation.delete();
    await messages.clear();
    if (clearContact) await contact.delete();
  }
}
