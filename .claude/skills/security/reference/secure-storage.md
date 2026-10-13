# flutter_secure_storage — setup, options, token pattern

Backed by the **iOS Keychain** and **Android Keystore / EncryptedSharedPreferences**. The right place for tokens, refresh tokens, and small secrets — never `SharedPreferences`.

## Dependency

```bash
flutter pub add flutter_secure_storage
```
Baseline `^9.2.4` — run the command for the latest; version-sensitive options are noted in `pub.dev/packages/flutter_secure_storage/changelog`.

## Platform options

Always pass explicit options so you control backing store and accessibility.

```dart
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock, // available after first unlock; not in backups
  ),
);
```

- **Android:** `encryptedSharedPreferences: true` uses AES via Keystore. minSdk 23+ is the smooth path; below that, behavior degrades.
- **iOS/macOS:** `KeychainAccessibility.first_unlock` is a sane default. `unlocked` is stricter (requires device unlocked at access time). `*_this_device` variants exclude the value from iCloud/device backups.

## Read / write / delete

```dart
Future<void> saveTokens({required String access, required String refresh}) async {
  await _storage.write(key: 'access_token', value: access);
  await _storage.write(key: 'refresh_token', value: refresh);
}

Future<String?> readAccess() => _storage.read(key: 'access_token');

Future<void> clearSession() async {
  await _storage.delete(key: 'access_token');
  await _storage.delete(key: 'refresh_token');
}
```

## Token store pattern

Wrap storage behind a small interface so the rest of the app never touches plugin types directly.

```dart
class TokenStore {
  TokenStore(this._storage);
  final FlutterSecureStorage _storage;

  Future<String?> get accessToken => _storage.read(key: 'access_token');
  Future<String?> get refreshToken => _storage.read(key: 'refresh_token');

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clear() => _storage.deleteAll();
}
```

Inject `TokenStore` (DI / provider) and let your auth interceptor read from it. The 401 refresh-and-retry flow (see `networking`) writes the new tokens back through `save`.

## Gotchas

- **Reads can fail / return null** after an OS Keystore reset, app-data clear, or backup restore. Treat a missing token as "logged out," not as a crash.
- **iOS Keychain survives app uninstall.** On a fresh install you may read a stale token. If you want a clean slate, detect first run (e.g. a flag in `SharedPreferences`) and `deleteAll()`.
- **Don't store large blobs** — Keychain/Keystore is for small secrets, not files or DB rows.
- **Web has no secure storage equivalent** — the plugin falls back to a far weaker store; do not rely on it for secrets on web.
- This protects data **at rest on device**; it does not make a leaked token safe — keep tokens short-lived and rotate via refresh.
