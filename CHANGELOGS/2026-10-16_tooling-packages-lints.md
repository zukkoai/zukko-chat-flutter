# Tooling: packages, git hygiene, constant_identifier_names

## #25 Packages / build_runner
- What: `hive_ce_generator` 1.11.3 -> 1.12.0 (`pubspec.yaml`); lock refreshed (analyzer 14.4.0, dart_style 3.1.14, vm_service 15.4.0, idb_shim 2.10.1+1, file_picker_web 4.2.0). Removed the invalid `--delete-conflicting-outputs` from `test.yml`, `release.yml`, `CLAUDE.md`, `doc/Develop.md`.
- Still blocked: `build_runner` 2.17.1 needs `build` >=5.0.0, but `hive_ce_generator` (all >=1.9.5, incl. 1.12.0) depends on `build ^4.0.0`. Other leftovers are transitive only: `cross_file` 0.4.0 (file_picker 13.1.0 / android_file_picker pin 0.3.x), `diffutil_dart` 5.0.0 (flutter_chat_ui 2.12.0), `material_color_utilities` 0.13.1 and `test_api` 0.7.15 (pinned by the Flutter SDK).

## #26 Incidental Flutter files
- Tracked project config stays: `analysis_options.yaml`, `example/pubspec.lock`, `example/ios/Podfile(.lock)`, `Flutter/Debug|Release.xcconfig`, Gradle files. Machine-generated stay ignored (`/pubspec.lock`, `.dart_tool/`, `.flutter-plugins*`, `local.properties`, `GeneratedPluginRegistrant.*`, `Generated.xcconfig`, `Pods/`, build outputs), per the Dart "Pubspec / lock files" guidance and the Flutter-generated `.gitignore` templates.
- Untracked (`git rm --cached`, files kept on disk): 28 golden-failure images in `test/ui/chat/styles/failures/` (written by `matchesGoldenFile` on failure); `**/test/**/failures/` added to `.gitignore`.

## #27 constant_identifier_names re-enabled
- Removed the `constant_identifier_names: false` override. Renamed to lowerCamelCase: `ZukkoChatExceptionType` (13 values), `ZukkoChatActionType.updatePresence`, `ZukkoChatEventMessageType` (8 values).
- Wire strings unchanged: exception types gain a `wire` field (used by `toString`), the other two already had one. Not stored in Hive. `test/core/wire_strings_test.dart` asserts every string.

## #28 homepage

- What: added `homepage: https://zukko.ai/en` to `pubspec.yaml`.
- Why: pub.dev shows it as the product link next to the repository and issue tracker.
