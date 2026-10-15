# Fix instance-key digest on web (true FNV-1a 64)

## Symptom
`cd example && flutter run -d chrome` failed to compile: `The integer literal 0xcbf29ce484222325 can't be represented exactly in JavaScript.`

## Root cause
`_digest()` in `lib/src/data/local/instance_key.dart` used native 64-bit int literals and wrapping multiplication, which web (53-bit doubles) cannot represent. It was also wrong on the VM: `toUnsigned(64)` is a no-op on a 64-bit int, so a digest with the top bit set printed as negative hex (e.g. `-509c23b379fe1374` for "a").

## Fix
`_digest` now uses `BigInt` with a 64-bit mask: true FNV-1a 64, always 16 lowercase hex chars, identical on VM and web. No migration: the `|||h:<digest>` key segment was added in the unreleased 0.1.0 refactor and never shipped, so no stored keys exist. Added `test/data/local/instance_key_test.dart` (known vectors "a" and "foobar", empty hash adds no segment, format check); passes on VM and `--platform chrome`.
