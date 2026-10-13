# drift — schema, DAO, schemaVersion + MigrationStrategy

`drift` is a typed, reactive SQL layer with first-class migrations. Codegen-based.

## Dependencies

```bash
flutter pub add drift drift_flutter
flutter pub add dev:drift_dev dev:build_runner
dart run build_runner watch -d   # regenerate .g.dart on change
```

## Tables + database

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_db.g.dart';

class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  // added in v2:
  DateTimeColumn get createdAt => dateTime().nullable()();
}

@DriftDatabase(tables: [Todos])
class AppDb extends _$AppDb {
  AppDb() : super(driftDatabase(name: 'app'));

  @override
  int get schemaVersion => 2; // BUMP on every schema change

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(todos, todos.createdAt); // v1 -> v2
          }
        },
      );
}
```

- `schemaVersion` and `onUpgrade` are **not optional** — every change to a table needs a version bump and a migration step.
- `onUpgrade` runs sequentially: handle each `from < N` so a user jumping multiple versions migrates through all of them.

## DAO / queries

```dart
extension TodoQueries on AppDb {
  Future<List<Todo>> allTodos() => select(todos).get();
  Stream<List<Todo>> watchTodos() => select(todos).watch(); // reactive
  Future<int> add(TodosCompanion t) => into(todos).insert(t);
  Future<bool> toggle(Todo t) => update(todos).replace(t.copyWith(done: !t.done));
}
```

`watch()` emits on every change — wire it straight into Riverpod/Bloc for live UI.

## Migration discipline

- Bump `schemaVersion` **and** add the matching `onUpgrade` branch in the same change.
- Use `drift_dev`'s schema tooling (`make-migrations` / exported schema files) to **test** migrations against real old schemas — see `reference/migrations.md`.
- Destructive changes (dropping/renaming columns) need explicit handling; SQLite has limited `ALTER` support, so drift may rebuild the table.
- Never edit `.g.dart` by hand; rerun build_runner.

## Gotchas

- Forgetting the version bump means `onUpgrade` never runs and the app opens against a stale schema → runtime SQL errors.
- A nullable new column migrates cleanly; a non-null column needs a default or a backfill step.
- Test the **v(old) → v(current)** path on a real database, not just a fresh install.
