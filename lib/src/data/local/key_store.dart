import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the 256-bit key of the encrypted Hive boxes lives. A seam so tests do
/// not need the platform keystore.
abstract interface class ChatwootKeyStore {
  /// The stored key, or `null` when none was stored yet.
  Future<List<int>?> read();

  Future<void> write(List<int> key);
}

/// Keychain (iOS) / Keystore-backed storage (Android) via flutter_secure_storage.
class SecureChatwootKeyStore implements ChatwootKeyStore {
  SecureChatwootKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // never leaves this device (no backup / migration to a new phone)
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _name = 'chatwoot_sdk_hive_key';

  final FlutterSecureStorage _storage;

  @override
  Future<List<int>?> read() async {
    final value = await _storage.read(key: _name);
    if (value == null) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      return null; // damaged: a new key is generated
    }
  }

  @override
  Future<void> write(List<int> key) =>
      _storage.write(key: _name, value: base64Encode(key));
}
