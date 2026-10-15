import 'zukko_chat_message.dart';

/// The one ordering of messages, oldest first: by the parsed `createdAt` (so
/// ISO strings, the `DateTime.toString()` strings older SDK versions stored and
/// plain dates compare correctly), ties by numeric id. Messages with an
/// unparseable timestamp sort first.
int compareByTimeThenId(ZukkoChatMessage a, ZukkoChatMessage b) {
  final byDate = _micros(a).compareTo(_micros(b));
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

int _micros(ZukkoChatMessage m) =>
    (DateTime.tryParse(m.createdAt) ?? epoch).microsecondsSinceEpoch;

/// Orders [messages] oldest first (see [compareByTimeThenId]). Used by storage
/// and UI.
List<ZukkoChatMessage> sortMessagesOldestFirst(
  Iterable<ZukkoChatMessage> messages,
) {
  final keyed = [for (final m in messages) (m, _micros(m))];
  keyed.sort((a, b) {
    final byDate = a.$2.compareTo(b.$2);
    return byDate != 0 ? byDate : a.$1.id.compareTo(b.$1.id);
  });
  return [for (final (m, _) in keyed) m];
}

/// The unix epoch; where unparseable timestamps sort.
final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
