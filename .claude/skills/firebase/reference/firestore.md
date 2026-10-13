# Cloud Firestore — offline, queries, snapshots, converters

## Contents
- [Offline persistence (default ON)](#offline-persistence-default-on)
- [Reads: get vs snapshots vs source](#reads-get-vs-snapshots-vs-source)
- [Writes are optimistic](#writes-are-optimistic)
- [Queries](#queries)
- [Typed converters (withConverter)](#typed-converters-withconverter)
- [Gotchas](#gotchas)

## Offline persistence (default ON)

On mobile, Firestore caches data and queues writes by default. This is great UX but changes read/write semantics:
- Reads can be served from cache (possibly stale).
- Writes resolve locally first and sync later.

Control it explicitly if needed:
```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true, // default true on mobile
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

## Reads: get vs snapshots vs source

| Approach | Behavior | Use when |
|---|---|---|
| `snapshots()` (listener) | Live cache → server updates stream in | Anything shown on screen that should stay current |
| `get()` | One read; may return **cached/stale** data offline or right after a write | One-off fetch where staleness is acceptable |
| `get(GetOptions(source: Source.server))` | Forces a server read (throws offline) | You must have fresh data |
| `get(GetOptions(source: Source.cache))` | Cache only | Explicit offline-first read |

```dart
// Live UI — prefer this:
StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  stream: doc.snapshots(),
  builder: (context, snap) { /* ... */ },
);

// Must be fresh:
final fresh = await doc.get(const GetOptions(source: Source.server));
```

`DocumentSnapshot.metadata.isFromCache` tells you whether data came from cache.

## Writes are optimistic

```dart
await col.add({'ownerId': uid, 'title': t}); // resolves locally; syncs when online
```
- The resolved Future means "written locally / queued," **not** "the server accepted it."
- Server-side rejection (e.g. rules denial) surfaces later, not at the await point in the offline-queued case.
- Use `FieldValue.serverTimestamp()` for authoritative timestamps; the local value is provisional until sync.

## Queries

```dart
final q = FirebaseFirestore.instance
    .collection('todos')
    .where('ownerId', isEqualTo: uid)   // scope to what rules allow
    .orderBy('createdAt', descending: true)
    .limit(20);
```
- Composite queries (multiple `where` + `orderBy`) often need a **composite index** — the error gives a one-click link to create it.
- Paginate with `startAfterDocument(lastDoc)`.
- **Scope queries to documents the rules permit** — a query touching denied docs throws `permission-denied`, it does not return a filtered subset.

## Typed converters (withConverter)

Avoid scattering `data()['field']` casts — convert at the reference.

```dart
final todos = FirebaseFirestore.instance.collection('todos').withConverter<Todo>(
  fromFirestore: (snap, _) => Todo.fromJson(snap.data()!..['id'] = snap.id),
  toFirestore: (todo, _) => todo.toJson()..remove('id'),
);

final snap = await todos.where('ownerId', isEqualTo: uid).get();
final List<Todo> items = snap.docs.map((d) => d.data()).toList();
```

## Gotchas

- `get()` returning stale/cached data is the most common surprise — use `snapshots()` or an explicit `source`.
- Don't treat an offline write's resolved Future as server confirmation.
- A `permission-denied` on a query usually means the query is broader than the rules allow — narrow it.
- Reads cost money: prefer one listener over polling `get()` in a loop; cap with `.limit()`.
- Disable persistence only for special cases (e.g. some web flows); it's an intentional UX trade-off.
