# Bundle the style fonts, drop google_fonts

## What
Manrope (smooth_silk), Geist (minimal_clean) and Onest (thread_feed) ship inside the package under `assets/fonts/<family>/` and are declared in `pubspec.yaml`. The tokens use `fontFamily: 'packages/chatwoot_sdk/<Family>'`. `ChatwootChatTheme.fontFamily` still overrides (the app must register its own font). The `google_fonts` dependency, its imports and the test setup that disabled runtime fetching are removed (root and example).

## Why
Privacy (no request to Google fonts servers) and offline first run.

## Weights and sizes
Only Regular (400) and SemiBold (600) are used by the styles (`FontWeight.w400`/`w600` in `lib/src/ui`), so only those are bundled: 6 TTFs, about 450 KB raw. Files are the exact static TTFs google_fonts 9.0.0 downloaded; sha256 and length were verified against its tables. `dart pub publish --dry-run`: 443 KB compressed archive (about 227 KB before). Italic is not bundled (not used; Flutter synthesizes it).

## License
SIL Open Font License 1.1: each family folder carries its `OFL.txt` (from google/fonts), shipped in the package.

## Test
`test/ui/chat/styles/bundled_fonts_test.dart`: each style resolves `packages/chatwoot_sdk/<Family>`, the override wins, declared assets and licenses exist.
