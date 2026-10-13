import 'package:hive_ce/hive.dart';

import '../../models/chatwoot_user.dart';

/// Holds at most one value of type [T] for one client instance
/// (its contact, conversation or user).
abstract class SingleStore<T> {
  Future<void> save(T value);
  T? get();
  Future<void> delete();
}

/// Hive-backed [SingleStore]. The value lives in a shared [Box] under the
/// client instance key, so instances never overwrite each other.
class HiveSingleStore<T> implements SingleStore<T> {
  HiveSingleStore(this._box, this._instanceKey);

  final Box<T> _box;
  final String _instanceKey;

  @override
  Future<void> save(T value) => _box.put(_instanceKey, value);

  @override
  T? get() => _box.get(_instanceKey);

  @override
  Future<void> delete() => _box.delete(_instanceKey);
}

/// In-memory [SingleStore]; one per client, never shared.
class MemorySingleStore<T> implements SingleStore<T> {
  T? _value;

  @override
  Future<void> save(T value) async => _value = value;

  @override
  T? get() => _value;

  @override
  Future<void> delete() async => _value = null;
}

/// Hive-backed user store that keeps secrets off disk: only
/// [ChatwootUser.toPersistable] is written, while the full user (with identity
/// hash and custom attributes) stays in memory for this process, because
/// creating a contact needs it.
class HiveUserStore implements SingleStore<ChatwootUser> {
  HiveUserStore(this._box, this._instanceKey);

  final Box<ChatwootUser> _box;
  final String _instanceKey;
  ChatwootUser? _full;

  @override
  Future<void> save(ChatwootUser value) {
    _full = value;
    return _box.put(_instanceKey, value.toPersistable());
  }

  @override
  ChatwootUser? get() => _full ?? _box.get(_instanceKey);

  @override
  Future<void> delete() {
    _full = null;
    return _box.delete(_instanceKey);
  }
}
