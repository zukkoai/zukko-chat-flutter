# Phase 4: strict lints, pubspec, unified sign-out, docs

## What
- `analysis_options.yaml`: `include: package:flutter_lints/flutter.yaml`, `strict-casts/inference/raw-types`, rules `unawaited_futures`, `avoid_print`, `always_declare_return_types`, `prefer_final_fields`, `use_build_context_synchronously`, `depend_on_referenced_packages`; `constant_identifier_names` off (public enum values keep their names). Same strictness in `example/analysis_options.yaml`.
- pubspec: version 0.1.0 (breaking), `webview_flutter_android` dependency, `webview_flutter_platform_interface` dev dependency (the `ignore_for_file` in `fake_webview_platform.dart` is gone).
- `chatwootSignOut(...)` (`lib/src/chatwoot_sign_out.dart`, exported): `ChatwootClient.clearData` + `ChatwootWidget.clearStoredConversation` in one call.
- `build.yaml`: codegen sources limited to `lib/**`, Hive registrar builders disabled (`lib/hive_registrar.g.dart` duplicated `hive_adapters.dart` and was unused).
- `.pubignore`: ships the gitignored `*.g.dart` files, keeps CLAUDE.md/TODO.md/CHANGELOGS/ out.
- `ChatwootEventMessageData`: unused mirror fields removed (account/inbox/sender/source ids, external source ids, updated_at, conversation, user).
- CI: `flutter analyze --fatal-infos` and `dart pub publish --dry-run`.
- Docs: CHANGELOG.md 0.1.0, README rewritten, CLAUDE.md Commands/Architecture/Tests, doc/ZukkoWidgetSdk.md §5, doc/Develop.md, TODO.md.

## Why / Symptom -> Fix
- F1/P18: `webview_flutter_android` was imported but undeclared and no lints were enforced, so "analyze clean" proved little. Fix: lints above; 68 findings fixed (below).
- SEC5: logout needed two unrelated calls. Fix: `chatwootSignOut`; tests `test/chatwoot_sign_out_test.dart` (native + webview, native only, webview only).
- Publishing: `dart pub publish` honours `.gitignore`, so the generated `*.g.dart` files would not have been in the package and it would not compile. Fix: `.pubignore`.
- `dart run build_runner build` failed locally when `example/ios/.symlinks` exists. Fix: `sources.include` in `build.yaml`.

## Lint fixes (68 findings)
- `strict-casts`/`strict-inference`: 4 `dynamic` -> `Map<String, dynamic>` casts in the Dio services (a non-map body still ends as the typed exception via `apiCall`), 1 test fake, 22 `dio.get<dynamic>`, 1 map literal in tests.
- `unawaited_futures` (5, `chatwoot_widget.dart`): webview setup calls are awaited in order before `loadRequest`; the external-link launch and `setOnShowFileSelector` are `unawaited`.
- Style: 12 `constant_identifier_names` (rule disabled, see above), 6 const constructors, 2 initializing formals, 2 missing braces, dangling library doc, `sort_child_properties_last`, `unnecessary_underscores`, 2 private types in test helpers (ignored with a reason), 1 string interpolation.
- No `// ignore` in `lib/`.

## Still open
See `TODO.md` (owner decisions: package name/homepage/description/publish_to; unused exception values kept: `UPDATE_CONTACT_FAILED`, `UPDATE_MESSAGE_FAILED`).
