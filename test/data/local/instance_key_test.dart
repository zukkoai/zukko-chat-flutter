import 'package:zukko_chat_flutter/src/data/local/instance_key.dart';
import 'package:flutter_test/flutter_test.dart';

String _key(String? hash) =>
    zukkoChatInstanceKey(baseUrl: 'u', websiteToken: 'i', identifierHash: hash);

String _digest(String hash) => _key(hash).split('|||h:').last;

void main() {
  // Known FNV-1a 64 vectors; must be identical on the VM and on web.
  test('digest is FNV-1a 64', () {
    expect(_digest('a'), 'af63dc4c8601ec8c');
    expect(_digest('foobar'), '85944171f73967e8');
  });

  test('empty or missing hash adds no segment', () {
    expect(_key(''), _key(null));
    expect(_key(''), isNot(contains('h:')));
  });

  test('digest is always 16 lowercase hex chars', () {
    for (final v in ['a', 'foobar', 'secret-hash', 'x' * 500, 'ünï']) {
      expect(_digest(v), matches(RegExp(r'^[0-9a-f]{16}$')));
    }
  });
}
