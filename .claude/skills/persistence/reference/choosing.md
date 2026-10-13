# Choosing a Flutter local-storage tool

Pick by the **shape of the data**, then commit to one. Detect what the project already uses (`pubspec.lock`) and follow it.

## Decision table

| Tool | Best for | Trade-off / status |
|---|---|---|
| `shared_preferences` | Small key/values: flags, prefs, last-route, theme mode | Not a DB, no queries/relations, **not for tokens** |
| `drift` | Typed relational SQL, joins, migrations, reactive queries | Codegen + build_runner; **current default for relational** |
| `sqflite` | Raw SQL with full control | Manual mapping + manual migrations; more boilerplate |
| `hive_ce` | Fast NoSQL key/object store, simple persistence | Codegen for adapters; **classic `hive` is unmaintained** |
| `objectbox` | High-performance object DB with relations | Native libs; great speed for object graphs |
| `isar` | — | **Largely abandoned — avoid for new projects** |

Rule of thumb:
- **Key/values** → `shared_preferences`.
- **Relational / queryable** → `drift` (or `sqflite` if you want raw SQL).
- **NoSQL objects** → `hive_ce` or `objectbox`.
- **Secrets/tokens** → `flutter_secure_storage` (see `security`) — never any of the above.

## When to use each

- **shared_preferences** — a handful of primitive settings the app reads at startup. If you find yourself "querying" prefs or storing lists of objects, switch to a database.
- **drift** — relational data with relationships, filtering, sorting, or that will evolve over time (migrations are first-class). Reactive `watch` queries integrate well with state management.
- **sqflite** — you want plain SQL and minimal abstraction, or you're porting existing SQL. You own the migration logic.
- **hive_ce** — fast local cache or document store without SQL. Drop-in successor to `hive`; same API, maintained.
- **objectbox** — performance-critical object persistence (large datasets, frequent reads/writes), object relations without writing SQL.

## Staleness / abandonment warnings

- **`hive` (classic)** is **unmaintained**. Migrate to **`hive_ce`** — it's the community-maintained fork with the same API and adapters.
- **`isar`** is **largely abandoned**; its 4.x line stalled. Don't start new projects on it. For existing isar code, plan a migration to `drift`/`objectbox`/`hive_ce`.
- `shared_preferences` **`getInstance()`** is the **legacy** API — prefer `SharedPreferencesAsync` / `SharedPreferencesWithCache`.

## Versions

Run `flutter pub add <pkg>` for the latest; read `pubspec.lock` for the project's current version. Where version-sensitive (drift codegen, hive_ce adapters), check `pub.dev/packages/<pkg>/changelog`. Baselines (verify with `flutter pub outdated`): `shared_preferences ^2.3.x`, `drift ^2.x` (+ `drift_dev`), `sqflite ^2.x`, `hive_ce ^2.x`, `objectbox ^4.x`.
