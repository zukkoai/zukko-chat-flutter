import 'package:hive_ce/hive.dart';

import '../../../shared/message_order.dart';
import '../../models/chatwoot_message.dart';

/// Messages of one client instance. [getMessages] always returns the messages
/// oldest first, for both implementations.
abstract class ChatwootMessagesDao {
  Future<void> saveMessage(ChatwootMessage message);
  Future<void> saveAllMessages(List<ChatwootMessage> messages);
  ChatwootMessage? getMessage(int messageId);
  List<ChatwootMessage> getMessages();

  /// Deletes this instance's messages.
  Future<void> clear();
}

/// Hive-backed messages. Box keys are `<instanceKey>|m|<messageId>`; `|` is
/// escaped inside instance keys so one instance's prefix never matches another's.
class PersistedChatwootMessagesDao implements ChatwootMessagesDao {
  PersistedChatwootMessagesDao(this._box, String instanceKey)
    : _prefix = '$instanceKey|m|';

  final Box<ChatwootMessage> _box;
  final String _prefix;

  String _key(int id) => '$_prefix$id';

  Iterable<String> get _ownKeys =>
      _box.keys.whereType<String>().where((k) => k.startsWith(_prefix));

  @override
  Future<void> saveMessage(ChatwootMessage message) =>
      _box.put(_key(message.id), message);

  @override
  Future<void> saveAllMessages(List<ChatwootMessage> messages) =>
      _box.putAll({for (final m in messages) _key(m.id): m});

  @override
  ChatwootMessage? getMessage(int messageId) => _box.get(_key(messageId));

  @override
  List<ChatwootMessage> getMessages() => sortMessagesOldestFirst(
    _ownKeys.map(_box.get).whereType<ChatwootMessage>(),
  );

  @override
  Future<void> clear() => _box.deleteAll(_ownKeys.toList());
}

class InMemoryChatwootMessagesDao implements ChatwootMessagesDao {
  final Map<int, ChatwootMessage> _messages = {};

  @override
  Future<void> saveMessage(ChatwootMessage message) async =>
      _messages[message.id] = message;

  @override
  Future<void> saveAllMessages(List<ChatwootMessage> messages) async {
    for (final m in messages) {
      _messages[m.id] = m;
    }
  }

  @override
  ChatwootMessage? getMessage(int messageId) => _messages[messageId];

  @override
  List<ChatwootMessage> getMessages() =>
      sortMessagesOldestFirst(_messages.values);

  @override
  Future<void> clear() async => _messages.clear();
}
