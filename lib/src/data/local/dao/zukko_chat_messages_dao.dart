import 'package:hive_ce/hive.dart';

import '../../models/message_order.dart';
import '../../models/zukko_chat_message.dart';

/// Messages of one client instance. [getMessages] always returns the messages
/// oldest first, for both implementations.
abstract class ZukkoChatMessagesDao {
  Future<void> saveMessage(ZukkoChatMessage message);
  Future<void> saveAllMessages(List<ZukkoChatMessage> messages);
  ZukkoChatMessage? getMessage(int messageId);
  List<ZukkoChatMessage> getMessages();

  /// Deletes this instance's messages.
  Future<void> clear();
}

/// Hive-backed messages. Box keys are `<instanceKey>|m|<messageId>`; `|` is
/// escaped inside instance keys so one instance's prefix never matches another's.
class PersistedZukkoChatMessagesDao implements ZukkoChatMessagesDao {
  PersistedZukkoChatMessagesDao(this._box, String instanceKey)
    : _prefix = '$instanceKey|m|';

  final Box<ZukkoChatMessage> _box;
  final String _prefix;

  String _key(int id) => '$_prefix$id';

  Iterable<String> get _ownKeys =>
      _box.keys.whereType<String>().where((k) => k.startsWith(_prefix));

  @override
  Future<void> saveMessage(ZukkoChatMessage message) =>
      _box.put(_key(message.id), message);

  /// Most messages kept per instance; the oldest go first so the box cannot
  /// grow without bound.
  static const maxStored = 500;

  @override
  Future<void> saveAllMessages(List<ZukkoChatMessage> messages) async {
    await _box.putAll({for (final m in messages) _key(m.id): m});
    final stored = getMessages(); // oldest first
    if (stored.length > maxStored) {
      await _box.deleteAll([
        for (final m in stored.take(stored.length - maxStored)) _key(m.id),
      ]);
    }
  }

  @override
  ZukkoChatMessage? getMessage(int messageId) => _box.get(_key(messageId));

  @override
  List<ZukkoChatMessage> getMessages() => sortMessagesOldestFirst(
    _ownKeys.map(_box.get).whereType<ZukkoChatMessage>(),
  );

  @override
  Future<void> clear() => _box.deleteAll(_ownKeys.toList());
}

class InMemoryZukkoChatMessagesDao implements ZukkoChatMessagesDao {
  final Map<int, ZukkoChatMessage> _messages = {};

  @override
  Future<void> saveMessage(ZukkoChatMessage message) async =>
      _messages[message.id] = message;

  @override
  Future<void> saveAllMessages(List<ZukkoChatMessage> messages) async {
    for (final m in messages) {
      _messages[m.id] = m;
    }
  }

  @override
  ZukkoChatMessage? getMessage(int messageId) => _messages[messageId];

  @override
  List<ZukkoChatMessage> getMessages() =>
      sortMessagesOldestFirst(_messages.values);

  @override
  Future<void> clear() async => _messages.clear();
}
