import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/src/data/local/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils/fixtures.dart';
import 'utils/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = HiveTestEnv();
  const base = 'https://x.test';
  final user = ChatwootUser(identifier: 'u', identifierHash: 'h');

  setUpAll(env.setUpAll);
  tearDown(env.tearDown);
  tearDownAll(env.tearDownAll);

  String keyFor(ChatwootUser u) => ChatwootClient.getClientInstanceKey(
    baseUrl: base,
    inboxIdentifier: 'inbox',
    userIdentifier: u.identifier,
    identifierHash: u.identifierHash,
  );

  test('clears the persisted data of that user only', () async {
    await env.open();
    final other = ChatwootUser(identifier: 'other');
    await LocalStorage.persisted(keyFor(user)).contact.save(contact());
    await LocalStorage.persisted(keyFor(other)).contact.save(contact());

    await chatwootSignOut(baseUrl: base, inboxIdentifier: 'inbox', user: user);

    expect(LocalStorage.persisted(keyFor(user)).contact.get(), isNull);
    expect(LocalStorage.persisted(keyFor(other)).contact.get(), isNotNull);
  });
}
