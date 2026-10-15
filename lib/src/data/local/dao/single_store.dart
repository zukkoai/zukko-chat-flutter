import 'package:hive_ce/hive.dart';

/// Holds at most one value of type [T] for one client instance
/// (its contact or conversation).
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
