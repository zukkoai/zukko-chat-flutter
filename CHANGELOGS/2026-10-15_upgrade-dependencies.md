# Upgrade dependencies to latest stable

## What
| Package | Old | New |
|---|---|---|
| google_fonts (root + example) | 8.2.1 | 9.0.0 |
| record | 6.2.1 | 7.1.2 (platform packages 1.x -> 2.x) |
| hive_ce | 2.21.0 | 2.22.0 |
| hive_ce_flutter | 2.4.0 | 2.5.0 |
| material_ui | 1.6.0 | 1.7.0 |

`build_runner` stays at 2.16.2 (latest 2.17.1): 2.17.1 needs `build` 5, while the newest `hive_ce_generator` (1.11.3) and `json_serializable` (6.14.1) still need `build` ^4. Upgrade it once hive_ce_generator supports build 5.
Other non-latest packages are transitive and pinned by the Flutter SDK or by that same `build` chain (cross_file, diffutil_dart, material_color_utilities, test_api, build, build_config).

## API changes
- record 7: dropped Android background service and iOS `manageAudioSession`; we use neither, `RecordConfig`/`startStream` unchanged. No code change.
- google_fonts 9: moved to material_ui/cupertino_ui; no API change for our usage.
- `ChatwootUpload.file` now uses a private named parameter (`this._size`) to satisfy `prefer_initializing_formals`.

## Why (voice tests)
`VoiceRecorderController._stop` awaited `StreamSubscription.cancel()` on an already finished stream; under fakeAsync that future stayed pending, so `onRecorded` never fired within the test's microtask flush. Not related to record. The cancel is now not awaited (the stream is already ended by `stop`).
