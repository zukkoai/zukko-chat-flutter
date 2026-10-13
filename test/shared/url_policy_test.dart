import 'package:chatwoot_sdk/src/shared/url_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateBaseUrl', () {
    test('https is accepted and returned parsed', () {
      expect(
        validateBaseUrl('https://chat.example.com/prefix').toString(),
        'https://chat.example.com/prefix',
      );
    });

    test('plain http is refused for a public host', () {
      expect(() => validateBaseUrl('http://example.com'), throwsArgumentError);
    });

    test('http is accepted for loopback and the Android emulator alias', () {
      for (final url in [
        'http://localhost:3000',
        'http://127.0.0.1:8080',
        'http://[::1]:3000',
        'http://10.0.2.2:3000',
        'http://LOCALHOST',
      ]) {
        expect(validateBaseUrl(url).toString(), isNotEmpty, reason: url);
      }
    });

    test('allowInsecure opens up http for any host', () {
      expect(
        validateBaseUrl('http://example.com', allowInsecure: true).host,
        'example.com',
      );
    });

    test('a host that merely starts like a loopback is not one', () {
      for (final url in [
        'http://localhost.evil.com',
        'http://127.0.0.1.evil.com',
        'http://10.0.2.20',
      ]) {
        expect(() => validateBaseUrl(url), throwsArgumentError, reason: url);
      }
    });

    test(
      'other schemes and non-urls are refused, even when insecure is on',
      () {
        for (final url in [
          'ftp://example.com',
          'file:///etc/passwd',
          'javascript:alert(1)',
          'ws://example.com',
          'example.com',
          '',
          'https://',
        ]) {
          expect(
            () => validateBaseUrl(url, allowInsecure: true),
            throwsArgumentError,
            reason: url,
          );
        }
      },
    );
  });
}
