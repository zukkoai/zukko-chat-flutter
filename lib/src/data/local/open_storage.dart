import '../../core/zukko_chat_client_exception.dart';
import '../../shared/sdk_log.dart';
import 'hive_database.dart';
import 'local_storage.dart';

/// The storage for the client with [instanceKey]: Hive-backed when
/// [persist] is true and Hive could be opened, in-memory otherwise.
///
/// Never throws. Problems are passed to [onError] (`STORAGE_FAILED`): Hive
/// could not be opened (the client then runs without persistence), or a box
/// was unreadable and recreated empty (the visitor starts a new session).
Future<LocalStorage> openStorage({
  required bool persist,
  required String instanceKey,
  required void Function(ZukkoChatException) onError,
}) async {
  if (!persist) return LocalStorage.inMemory();
  try {
    await HiveDatabase.openDB();
    for (final name in HiveDatabase.takeRecreated()) {
      onError(
        ZukkoChatException(
          'local storage "$name" was unreadable and has been reset',
          ZukkoChatExceptionType.storageFailed,
        ),
      );
    }
    return LocalStorage.persisted(instanceKey);
  } catch (e, st) {
    sdkLog('persistence unavailable: ${e.runtimeType}');
    onError(
      e is ZukkoChatException
          ? e
          : ZukkoChatException(
              'local storage unavailable, continuing without persistence: '
              '${e.runtimeType}',
              ZukkoChatExceptionType.storageFailed,
              error: e,
              stackTrace: st,
            ),
    );
    return LocalStorage.inMemory();
  }
}
