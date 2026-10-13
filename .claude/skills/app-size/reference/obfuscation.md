# Obfuscation & symbols

Obfuscation renames Dart symbols in the AOT build. It modestly shrinks size and hides identifiers — but it is **not security**, and it requires symbol files to keep crashes readable.

## The command (both flags, always)

```bash
flutter build appbundle --obfuscate --split-debug-info=build/symbols
flutter build ipa       --obfuscate --split-debug-info=build/symbols
```
- **`--obfuscate` requires `--split-debug-info=<dir>`** — they go together. `--obfuscate` alone is a known mistake.
- `<dir>` (e.g. `build/symbols`) receives the mapping/debug-info files.

## Back up the symbols — per release

`build/symbols` is the **only** way to de-obfuscate that build's stack traces. If you lose it, every crash from that version is permanently unreadable hex.

- Archive `build/symbols/` for **each released version** (CI artifact, release bucket, or your crash-reporter's symbol store).
- Upload to your crash reporter (Crashlytics `crashlytics:symbols:upload`, Sentry symbol upload) — cross-ref `observability` and `ci-cd`.
- Symbolicate after the fact: `flutter symbolize -i <stack.txt> -d build/symbols/app.android-arm64.symbols`.

## Obfuscation is NOT encryption / security

The single biggest myth. Obfuscation:
- **Renames** classes/methods/fields to short tokens. That's it.
- Does **not** encrypt, does **not** hide string literals, does **not** stop reverse engineering — the app still runs, so the code is still extractable.

**Never** embed API keys, secrets, or proprietary logic in the client expecting obfuscation to protect them. Keep secrets server-side (cross-ref `security`).

## What obfuscation breaks

Anything that depends on **symbol names at runtime** breaks silently in release (works in debug, fails after obfuscation):

```dart
// BREAKS — renamed at build time
switch (obj.runtimeType.toString()) { case 'User': ... }   // type name is now 'a1b'
final key = T.toString();                                   // unstable across builds
if (widget.runtimeType.toString() == 'HomePage') ...        // brittle
final tag = MyEnum.values.first.runtimeType.toString();     // unreliable

// SAFE — use explicit, stable identifiers
const kind = 'User';                                        // your own constant
switch (obj) { case User _: ... }                           // pattern match on the real type
final key = MyEnum.active.name;  // OK for enum names (preserved), but don't key off Type names
```

Watch for:
- `runtimeType.toString()` used in logic, logging keys, or serialization.
- JSON/serialization that keys off **class names** (some hand-rolled (de)serializers).
- Reflection-like dispatch (`dart:mirrors` isn't available in AOT anyway, but name-based registries are).
- `Type` used as a map key compared by string name.

Prefer explicit string constants, `sealed`/pattern matching on real types, and code-generated serializers (json_serializable) that don't rely on runtime names.

## Verify
- Release build runs; features that previously used `runtimeType`/type names still work.
- A forced test crash symbolicates cleanly with the archived symbols.
- Symbols for the shipped version are stored somewhere durable.
