import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/src/data/local/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui/webview/fake_webview_platform.dart';
import 'utils/fixtures.dart';
import 'utils/hive_test_env.dart';

class _Store implements ChatwootTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String scope) async => values[scope];

  @override
  Future<void> write(String scope, String token) async =>
      values[scope] = token;

  @override
  Future<void> delete(String scope) async => values.remove(scope);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = HiveTestEnv();
  late FakeWebViewPlatform platform;
  const base = 'https://x.test';
  final user = ChatwootUser(identifier: 'u', identifierHash: 'h');

  setUpAll(env.setUpAll);
  setUp(() => platform = FakeWebViewPlatform.install());
  tearDown(env.tearDown);
  tearDownAll(env.tearDownAll);

  String keyFor(ChatwootUser u) => ChatwootClient.getClientInstanceKey(
    baseUrl: base,
    inboxIdentifier: 'inbox',
    userIdentifier: u.identifier,
    identifierHash: u.identifierHash,
  );

  test('clears the native data and the webview session in one call', () async {
    await env.open();
    final other = ChatwootUser(identifier: 'other');
    await LocalStorage.persisted(keyFor(user)).contact.save(contact());
    await LocalStorage.persisted(keyFor(other)).contact.save(contact());

    await chatwootSignOut(
      baseUrl: base,
      inboxIdentifier: 'inbox',
      websiteToken: 'site',
      user: user,
      tokenStore: _Store(),
    );

    expect(LocalStorage.persisted(keyFor(user)).contact.get(), isNull);
    expect(LocalStorage.persisted(keyFor(other)).contact.get(), isNotNull);
    expect(platform.log, ['clearCookies', 'clearStorage', 'clearCache']);
  });

  test('inboxIdentifier only: webview untouched', () async {
    await chatwootSignOut(baseUrl: base, inboxIdentifier: 'inbox', user: user);

    expect(platform.log, isEmpty);
  });

  test('websiteToken only: native storage untouched', () async {
    await env.open();
    await LocalStorage.persisted(keyFor(user)).contact.save(contact());

    await chatwootSignOut(
      baseUrl: base,
      websiteToken: 'site',
      user: user,
      tokenStore: _Store(),
    );

    expect(LocalStorage.persisted(keyFor(user)).contact.get(), isNotNull);
    expect(platform.log, ['clearCookies', 'clearStorage', 'clearCache']);
  });
}
