import 'dart:io';

import 'package:zukko_chat_flutter/src/data/local/key_store.dart';
import 'package:zukko_chat_flutter/src/data/local/hive_database.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Real Hive in a unique temp directory, so every test file is isolated.
///
/// ```dart
/// final env = HiveTestEnv();
/// setUpAll(env.setUpAll);
/// tearDown(env.tearDown);
/// tearDownAll(env.tearDownAll);
/// ```
/// Tests then call `HiveDatabase.openDB()` themselves (or let the SDK do it).
class HiveTestEnv {
  late final Directory dir;

  /// In-memory stand-in for the platform keystore; survives [tearDown] like the
  /// real one survives a process restart.
  final keys = FakeKeyStore();

  void setUpAll() {
    HiveDatabase.keyStore = keys;
    dir = Directory.systemTemp.createTempSync('chatwoot_sdk_hive_');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
  }

  /// Wipes every box (open or not) so the next test starts with no data and no
  /// open boxes, like a fresh process.
  Future<void> tearDown() async {
    await Hive.deleteFromDisk();
    // boxes that were closed (not deleted) by the SDK are not known to Hive
    for (final entity in dir.listSync()) {
      entity.deleteSync(recursive: true);
    }
    keys
      ..key = null
      ..writes = 0;
  }

  Future<void> tearDownAll() async {
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  /// Convenience: open the SDK boxes.
  Future<void> open() => HiveDatabase.openDB();
}

/// [ZukkoChatKeyStore] without the platform channel.
class FakeKeyStore implements ZukkoChatKeyStore {
  List<int>? key;
  var writes = 0;

  @override
  Future<List<int>?> read() async => key;

  @override
  Future<void> write(List<int> key) async {
    writes++;
    this.key = key;
  }
}
