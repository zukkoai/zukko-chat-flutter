# Leveled SDK logs and quiet identity handling

## What
- `sdkLog` takes a level (`SdkLogLevel.error` / `warning` / `info`); output is `[zukko_chat] ERROR: ...`, `WARNING: ...` or plain. Still debug-only.
- A rejected identifier hash (401 on `set_user`) logs ONE error line saying whether `identifierHash` is missing or wrong (text in `identityValidationMessage`, one place to append a docs link later).
- An identifier without a hash on an inbox that does not enforce identity validation is now fully silent: no log, no `onError(IDENTITY_NOT_VERIFIED)`.
- `IDENTITY_NOT_VERIFIED` stays in the enum (same wire string) but is no longer emitted.

## Why
Every chat open printed two noisy lines for a missing hash, and there was no way to tell failures from flow info.

## Fix
Levels assigned per call site (failures = warning, developer-fixable = error, ignored/dropped = info); removed the controller's duplicate `error:` line and the `_warnUnverified` emission. Tests: `test/shared/sdk_log_test.dart`, "identity logging" group in `widget_session_hardening_test.dart`.
