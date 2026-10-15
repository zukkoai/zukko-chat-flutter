import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils/fixtures.dart';
import 'utils/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = HiveTestEnv();
  const base = 'https://x.test';
  final user = ZukkoChatUser(identifier: 'u', identifierHash: 'h');

  setUpAll(env.setUpAll);
  tearDown(env.tearDown);
  tearDownAll(env.tearDownAll);

  String keyFor(ZukkoChatUser u) => ZukkoChatClient.getClientInstanceKey(
    baseUrl: base,
    websiteToken: 'inbox',
    userIdentifier: u.identifier,
    identifierHash: u.identifierHash,
  );

  test('clears the persisted data of that user only', () async {
    await env.open();
    final other = ZukkoChatUser(identifier: 'other');
    await LocalStorage.persisted(keyFor(user)).contact.save(contact());
    await LocalStorage.persisted(keyFor(other)).contact.save(contact());

    await zukkoChatSignOut(baseUrl: base, websiteToken: 'inbox', user: user);

    expect(LocalStorage.persisted(keyFor(user)).contact.get(), isNull);
    expect(LocalStorage.persisted(keyFor(other)).contact.get(), isNotNull);
  });
}
