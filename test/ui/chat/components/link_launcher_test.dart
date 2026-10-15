import 'package:chatwoot_sdk/src/ui/chat/components/link_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds http(s) and www links, trims trailing punctuation', () {
    const text = 'See https://a.test/x?y=1, and www.b.test. Not ftp://c.test';
    final links = findLinks(text);

    expect(links.map((l) => l.uri.toString()), [
      'https://a.test/x?y=1',
      'https://www.b.test',
    ]);
    expect(
      text.substring(links.first.start, links.first.end),
      'https://a.test/x?y=1',
    );
  });

  test('parseLink accepts only http(s) with a host', () {
    expect(parseLink('https://a.test'), isNotNull);
    expect(parseLink('javascript:alert(1)'), isNull);
    expect(parseLink('https://'), isNull);
  });
}
