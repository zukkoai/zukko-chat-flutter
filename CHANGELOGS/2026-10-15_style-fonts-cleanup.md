# Design fonts for the chat styles, unused assets removed

## What
- New dependency `google_fonts`: Smooth Silk uses Manrope, Minimal Clean Geist, Thread Feed Onest (as in the design). `ChatwootChatTheme.fontFamily` still forces one font; `fromThemeData` no longer copies the app font.
- Widget tests set `GoogleFonts.config.allowRuntimeFetching = false`.
- Removed unused files: `assets/logo_grey.png` (old Chatwoot footer), `example/assets/chatwoot_logo.png`, `example/lib/voice_format.dart`, and the `assets:` entries in both pubspecs.

## Note
Run `flutter pub get` in the package and in `example/` (pubspec.lock changes).
