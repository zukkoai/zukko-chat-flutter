# Migrations — cross-package patterns + testing

A schema change without a migration is the **#1 persistence omission**: existing users upgrade and the app crashes or silently loses data. Every package has its own mechanism — none is optional.

## Contents
- [The rule](#the-rule)
- [Per-package mechanism](#per-package-mechanism)
- [Patterns by change type](#patterns-by-change-type)
- [Testing migrations](#testing-migrations)
- [Checklist](#checklist)

## The rule

When the persisted shape changes, ship the migration **in the same change** as the schema bump. Always test the **old-version → new-version** path on data created at the old version, not a clean install.

## Per-package mechanism

| Package | Version field | Migration hook | Footgun |
|---|---|---|---|
| `drift` | `schemaVersion` | `MigrationStrategy.onUpgrade(m, from, to)` | bump version but forget `onUpgrade` |
| `sqflite` | `version:` in `openDatabase` | `onUpgrade(db, old, new)` | `ALTER TABLE` can't drop/rename columns |
| `hive_ce` | none (additive evolution) | manual transform + meta "dataVersion" | renumbering `typeId`/`@HiveField` corrupts data |
| `objectbox` | model handled by codegen | mostly automatic; manual for data transforms | renaming entities/props needs uid annotations |
| `shared_preferences` | none | read old key → write new key on launch | leaving stale keys around |

## Patterns by change type

**Add a field/column (most common):**
- drift/sqflite: `addColumn` / `ALTER TABLE ... ADD COLUMN` in `onUpgrade`; make it nullable or give a default.
- hive_ce: new `@HiveField` index, nullable or defaulted.

**Remove/rename:**
- SQLite (drift/sqflite): create new table → copy data → drop old → rename (SQLite can't simply drop/rename).
- hive_ce: leave the old `@HiveField` index reserved; map in code; never reuse the index.

**Transform values (e.g. split a name field):**
- Read old rows/objects, compute new values, write them back inside the migration step.
- For hive_ce, gate the transform on a stored `dataVersion` so it runs exactly once:
```dart
final meta = await Hive.openBox('meta');
final v = meta.get('dataVersion', defaultValue: 1) as int;
if (v < 2) { /* transform all records */ await meta.put('dataVersion', 2); }
```

**Migrating between packages** (e.g. classic `hive`→`hive_ce`, or `isar`→`drift`):
- Read all records from the old store, write into the new store on first launch, then mark done. Keep the old store readable until the migration completes successfully.

## Testing migrations

- **drift:** use `drift_dev` schema exports + `verifySelfMigration` / generated test helpers to assert each `vN→vN+1` step against the real old schema.
- **sqflite:** in a test, create the DB at the old `version` with old data, reopen at the new `version`, assert `onUpgrade` produced the expected schema/data.
- **hive_ce:** seed a box with old-shaped data, run the transform, assert results and that `dataVersion` advanced.
- Always cover a user **skipping versions** (v1 → v3): each intermediate step must run.

## Checklist

- [ ] Schema/version bumped **and** the matching migration written in the same change.
- [ ] New columns/fields nullable or defaulted; non-null ones backfilled.
- [ ] Hive `typeId`/`@HiveField` indexes never reused or renumbered.
- [ ] Multi-version skip path handled (sequential `from < N` / `oldVersion < N`).
- [ ] Migration tested on data created at the previous version (not just fresh install).
- [ ] No secrets migrated into a plain store — those belong in `flutter_secure_storage`.
