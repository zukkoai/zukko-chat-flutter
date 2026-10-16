import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/shared/url_policy.dart';

void main() {
  test('isHttpUrl', () {
    expect(isHttpUrl('http://a.b/c'), isTrue);
    expect(isHttpUrl('HTTPS://a.b'), isTrue);
    expect(isHttpUrl('ftp://a.b'), isFalse);
    expect(isHttpUrl('/local/file.png'), isFalse);
    expect(isHttpUrl(''), isFalse);
    expect(isHttpUrl(null), isFalse);
  });

  test('isHttpsUrl', () {
    expect(isHttpsUrl('https://a.b'), isTrue);
    expect(isHttpsUrl('HtTpS://a.b'), isTrue);
    expect(isHttpsUrl('http://a.b'), isFalse);
    expect(isHttpsUrl(null), isFalse);
  });
}
