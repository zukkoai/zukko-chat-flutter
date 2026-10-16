# Logout docs and immediate on-disk wipe

## What

- README has a `Logout` section: `zukkoChatSignOut(...)` for a known user, `ZukkoChatClient.clearAllData()` for anonymous visitors.
- `HiveDatabase.clearInstanceFamily` compacts each box right after the wipe (`clearAll` needs no compact: Hive's `box.clear()` already truncates the file).

## Why

`box.deleteAll()` only appends tombstones. The old encrypted frames (JWT, messages) stayed in the `.hive` file until Hive compacted it on its own, so logged-out data was still on disk.

## Fix

`await box.compact()` after `deleteAll`. Box names, keys and type ids are unchanged. A test checks the box file shrinks right after the wipe.
