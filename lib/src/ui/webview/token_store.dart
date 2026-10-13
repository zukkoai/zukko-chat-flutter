import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the widget keeps its conversation token (keyed by scope, see
/// `conversationTokenScope`).
abstract interface class ChatwootTokenStore {
  Future<String?> read(String scope);
  Future<void> write(String scope, String token);
  Future<void> delete(String scope);
}

/// Default store: the platform keychain / keystore.
class SecureTokenStore implements ChatwootTokenStore {
  const SecureTokenStore([this._storage = defaultStorage]);

  /// iOS: keep the token on this device only (no backup/restore to another
  /// device, readable after the first unlock).
  static const defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String scope) => _storage.read(key: scope);

  @override
  Future<void> write(String scope, String token) =>
      _storage.write(key: scope, value: token);

  @override
  Future<void> delete(String scope) => _storage.delete(key: scope);
}
