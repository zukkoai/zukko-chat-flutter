import '../data/models/chatwoot_message.dart';

/// Orders [messages] oldest first.
///
/// Sorts by the parsed `createdAt` (so ISO strings, the `DateTime.toString()`
/// strings older SDK versions stored and plain dates compare correctly), and
/// breaks ties by numeric id. Messages with an unparseable timestamp sort first.
/// The single ordering used by storage and UI.
List<ZukkoChatMessage> sortMessagesOldestFirst(
  Iterable<ZukkoChatMessage> messages,
) {
  final keyed = [
    for (final m in messages)
      (m, (DateTime.tryParse(m.createdAt) ?? _epoch).microsecondsSinceEpoch),
  ];
  keyed.sort((a, b) {
    final byDate = a.$2.compareTo(b.$2);
    return byDate != 0 ? byDate : a.$1.id.compareTo(b.$1.id);
  });
  return [for (final (m, _) in keyed) m];
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
