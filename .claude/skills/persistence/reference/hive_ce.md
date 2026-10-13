# hive_ce — adapters, typeId discipline, init

`hive_ce` (Hive Community Edition) is the maintained successor to the unmaintained classic `hive`. Fast NoSQL key/object store, same API.

## Dependency

```bash
flutter pub add hive_ce hive_ce_flutter
flutter pub add dev:hive_ce_generator dev:build_runner
dart run build_runner build -d
```

## Init + open boxes

```dart
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

Future<void> main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(TodoAdapter());        // generated
  final box = await Hive.openBox<Todo>('todos');
  runApp(MyApp(box: box));
}
```

Open a box before using it; a typed box (`openBox<Todo>`) keeps reads type-safe.

## Adapters + the typeId rule

```dart
import 'package:hive_ce/hive.dart';
part 'todo.g.dart';

@HiveType(typeId: 0) // PERMANENT — never reuse or renumber
class Todo extends HiveObject {
  Todo({required this.title, this.done = false, this.createdAt});

  @HiveField(0) String title;       // field indexes are also permanent
  @HiveField(1) bool done;
  @HiveField(2) DateTime? createdAt; // added later — give new index, default/nullable
}
```

**`typeId` discipline (the data-corruption footgun):**
- A `typeId` identifies a type in the binary format. **Renumbering or reusing a `typeId` corrupts existing data** — Hive will deserialize old bytes against the wrong type.
- Same for `@HiveField` indexes: never reuse an index for a different field.
- **Evolving a model:** only **add** new `@HiveField` indexes (nullable or with a sensible default). Don't repurpose or remove old ones; if a field is gone, leave its index reserved.

## CRUD

```dart
await box.put('id1', Todo(title: 'Buy milk'));
final todo = box.get('id1');
await box.delete('id1');
box.watch(key: 'id1').listen((event) { /* reactive */ });
```

## Migration approach

Hive has no `schemaVersion`/`onUpgrade`. You migrate by **additive, backward-compatible** changes:
- New fields: new `@HiveField` index, nullable or defaulted — old records read fine.
- Larger restructures: read old objects, transform, write the new shape (optionally into a new box), keyed by a stored "data version" flag in a meta box. See `reference/migrations.md`.

## Gotchas

- **Never renumber/reuse `typeId` or `@HiveField` indexes** — silent data corruption.
- `Hive.initFlutter()` must run before any box access.
- Lazy boxes (`openLazyBox`) keep values on disk until read — use for large datasets to save memory.
- Hive is not encrypted by default; for secrets use `flutter_secure_storage`, not an encrypted box as a substitute.
