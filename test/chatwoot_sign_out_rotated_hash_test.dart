import 'package:zukko_chat_flutter/zukko_chat_flutter.dart';
import 'package:zukko_chat_flutter/src/data/local/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils/fixtures.dart';
import 'utils/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = HiveTestEnv();
  const base = 'https://x.test';

  setUpAll(env.setUpAll);
  tearDown(env.tearDown);
  tearDownAll(env.tearDownAll);

  String key(String? id, {String? hash, String site = 'inbox'}) =>
      ZukkoChatClient.getClientInstanceKey(
        baseUrl: base,
        websiteToken: site,
        userIdentifier: id,
        identifierHash: hash,
      );

  Future<void> fill(String k) async {
    final s = LocalStorage.persisted(k);
    await s.contact.save(contact());
    await s.conversation.save(conversation());
    await s.messages.saveMessage(message(1));
    await s.user.save(ZukkoChatUser(identifier: 'x'));
  }

  bool has(String k) {
    final s = LocalStorage.persisted(k);
    return s.contact.get() != null ||
        s.conversation.get() != null ||
        s.messages.getMessages().isNotEmpty ||
        s.user.get() != null;
  }

  test(
    'records of the same user under every hash digest are removed (14)',
    () async {
      await env.open();
      final keys = [
        key('u'),
        key('u', hash: 'old-hash'),
        key('u', hash: 'rotated-hash'),
      ];
      final others = [
        key('u2', hash: 'old-hash'), // another user
        key('other'),
        key('u', hash: 'old-hash', site: 'inbox2'), // another inbox
        key(null),
      ];
      for (final k in [...keys, ...others]) {
        await fill(k);
      }

      // signing out with the current hash only
      await zukkoChatSignOut(
        baseUrl: base,
        websiteToken: 'inbox',
        user: ZukkoChatUser(identifier: 'u', identifierHash: 'rotated-hash'),
      );

      for (final k in keys) {
        expect(has(k), isFalse, reason: k);
      }
      for (final k in others) {
        expect(has(k), isTrue, reason: k);
      }
    },
  );

  test('without a user only the anonymous records go', () async {
    await env.open();
    await fill(key(null));
    await fill(key('u', hash: 'h'));

    await zukkoChatSignOut(baseUrl: base, websiteToken: 'inbox');

    expect(has(key(null)), isFalse);
    expect(has(key('u', hash: 'h')), isTrue);
  });

  test('clearAllData wipes everything', () async {
    await env.open();
    await fill(key('u', hash: 'h'));
    await fill(key(null));

    await ZukkoChatClient.clearAllData();

    expect(has(key('u', hash: 'h')), isFalse);
    expect(has(key(null)), isFalse);
  });
}
