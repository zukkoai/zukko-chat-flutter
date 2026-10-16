import '../shared/best_effort.dart';
import 'local/local_storage.dart';
import 'models/zukko_chat_message.dart';
import 'remote/api/zukko_chat_client_service.dart';

/// What this process knows about the conversation's messages: a cache of the
/// ones seen (by id), the cursor of the newest server message, paged fetching
/// and best-effort persisting.
///
/// Persisting is not awaited on the live path, so storage can lag behind:
/// duplicate detection and the author check on updates go through the cache
/// first.
class MessageSync {
  MessageSync(this._service, this._storage);

  final ZukkoChatClientService _service;
  final LocalStorage _storage;

  /// Upper bound of the cache; the oldest entries go first (storage still
  /// answers for them).
  static const _knownCap = 2000;

  /// Messages in a latest / `before` page (server side, `MessageFinder`).
  static const pageSize = 20;

  /// The server caps a page at 100 messages.
  static const _afterPageSize = 100;

  /// Pages fetched at most by one `after` catch-up.
  static const _maxAfterPages = 20;

  final _known = <int, ZukkoChatMessage>{};

  int? _cursor;

  /// Highest message id received from a fetch or a socket event; null if none.
  /// Ids returned by our own REST sends never move it: a send can return an id
  /// above messages we have not received yet, and the reconnect refetch
  /// (`after=cursor`) would skip them.
  int? get cursor => _cursor;

  void remember(ZukkoChatMessage m) {
    _known[m.id] = m;
    while (_known.length > _knownCap) {
      _known.remove(_known.keys.first);
    }
  }

  /// A message that came from the server (fetch or event): moves the cursor.
  void noteServer(ZukkoChatMessage m) {
    remember(m);
    if (m.id > (_cursor ?? 0)) _cursor = m.id;
  }

  /// The message with [id], from the cache or the storage.
  ZukkoChatMessage? find(int id) =>
      _known[id] ?? _storage.messages.getMessage(id);

  bool isKnown(int id) => find(id) != null;

  /// An update edits a message, it must not change who wrote it.
  static bool changesAuthor(ZukkoChatMessage known, ZukkoChatMessage updated) {
    final knownSender = known.sender?.id;
    return (known.messageType != null &&
            known.messageType != updated.messageType) ||
        (knownSender != null && knownSender != updated.sender?.id);
  }

  /// Persists [message]; a failure is only logged.
  Future<void> save(ZukkoChatMessage message) => bestEffort(
    () => _storage.messages.saveMessage(message),
    'persisting a message',
  );

  /// The messages of another conversation are gone.
  void forgetKnown() => _known.clear();

  /// The previous contact's messages are gone: forget cache and cursor.
  void reset() {
    _known.clear();
    _cursor = null;
  }

  /// Fetches the page of messages just older than message id [before]
  /// (oldest first). Remembers them but neither persists them nor moves the
  /// cursor: older pages live in memory only, so they can never push newer
  /// messages out of the stored newest page (`PersistedZukkoChatMessagesDao.maxStored`).
  Future<List<ZukkoChatMessage>> fetchBefore(int before) async {
    final page = await _service.getMessages(before: before);
    page.forEach(remember);
    return page;
  }

  /// Fetches the latest messages, or with [after] everything newer than that
  /// message id (pages of up to 100 until the server has no more), remembers
  /// and persists them. Throws what the service throws.
  Future<List<ZukkoChatMessage>> fetch({int? after}) async {
    final messages = <ZukkoChatMessage>[];
    if (after == null) {
      messages.addAll(await _service.getMessages());
    } else {
      var from = after;
      for (var pages = 0; pages < _maxAfterPages; pages++) {
        final page = await _service.getMessages(after: from);
        messages.addAll(page);
        final newest = page.fold(from, (top, m) => m.id > top ? m.id : top);
        // the server caps a page: ask again from the newest id
        if (page.length < _afterPageSize || newest == from) break;
        from = newest;
      }
    }
    messages.forEach(noteServer);
    await bestEffort(
      () => _storage.messages.saveAllMessages(messages),
      'persisting messages',
    );
    return messages;
  }
}
