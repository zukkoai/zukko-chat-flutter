# sqflite — open + onCreate/onUpgrade

Raw SQLite with full control. You write the SQL and you own the migrations.

## Dependency

```bash
flutter pub add sqflite path
```

## Open with versioned migrations

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<Database> openDb() async {
  final path = join(await getDatabasesPath(), 'app.db');
  return openDatabase(
    path,
    version: 2, // BUMP on every schema change
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE todos(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          done INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER
        )
      ''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE todos ADD COLUMN createdAt INTEGER');
      }
      // add an `if (oldVersion < 3)` block for the next change, etc.
    },
  );
}
```

- **`version` + `onUpgrade` are mandatory.** Bumping `version` without an `onUpgrade` branch means the schema never changes for existing users → SQL errors.
- `onCreate` runs only for fresh installs; `onUpgrade` runs for existing users. Keep them in sync (a new install must end up at the same schema an upgraded one does).
- Sequential `if (oldVersion < N)` blocks let a user skipping versions migrate through each step.

## CRUD

```dart
await db.insert('todos', {'title': t, 'done': 0});
final rows = await db.query('todos', where: 'done = ?', whereArgs: [0]);
await db.update('todos', {'done': 1}, where: 'id = ?', whereArgs: [id]);
await db.delete('todos', where: 'id = ?', whereArgs: [id]);
```

Always use `whereArgs` placeholders — never string-interpolate values (SQL injection + quoting bugs).

## Gotchas

- SQLite has no `bool`/`DateTime`; store as `INTEGER` (0/1, epoch ms) and convert in Dart.
- `ALTER TABLE` in SQLite can't drop/rename columns easily — to restructure, create a new table, copy data, drop the old one, rename.
- Test the **old→new** upgrade path on a database created at the previous version, not just a clean install.
- For typed models, joins, and reactive queries, prefer `drift` over hand-rolled sqflite.
