# Fix file_picker version resolution

## Symptom
`flutter pub get` failed in the root and in `example/`: `file_picker ^10` needs `win32 ^5.9.0`, while `flutter_secure_storage 11.2.0` pulls `flutter_secure_storage_windows ^4.2.2` (`win32 ^6.0.1`).

## Root cause
`file_picker` 10.x is pinned to win32 5.x, which conflicts with win32 6.x required by `flutter_secure_storage` 11.

## Fix
`file_picker` bumped to `^13.0.0` (resolves 13.1.0). Its API changed: `FilePicker.pickFiles` is static and returns `List<PlatformFile>`; no `allowMultiple`/`withData`, and `PlatformFile` has no `bytes`/`size`. `attachment_picker.dart` now uses `readAsBytes()` on web and `length()` for the size on native.
