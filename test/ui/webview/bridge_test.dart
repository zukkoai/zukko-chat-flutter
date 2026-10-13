import 'dart:convert';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/src/ui/webview/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pulls the JS string-literal argument out of `window.postMessage(<lit>);`
/// the way a JS engine would read it (a JSON string is a valid JS literal).
String _argOf(String script) {
  expect(script, startsWith('window.postMessage('));
  expect(script, endsWith(');'));
  return jsonDecode(
    script.substring('window.postMessage('.length, script.length - 2),
  ) as String;
}

void main() {
  group('script escaping (U1)', () {
    const nasty = "O'Brien \"the\" \n\\ <b>é</b> ";

    test(
      'user data with quotes, apostrophes, newlines round-trips exactly',
      () {
        final script = generateScripts(
          user: ChatwootUser(identifier: 'i', name: nasty),
        );
        final arg = _argOf(script);
        expect(arg, startsWith(wootPrefix));
        final payload = jsonDecode(arg.substring(wootPrefix.length)) as Map;

        expect(payload['event'], 'set-user');
        expect((payload['user'] as Map)['name'], nasty);
      },
    );

    test('a name that tries to close the string stays inside it', () {
      const evil = "');alert(1);//";
      final script = generateScripts(
        user: ChatwootUser(identifier: 'i', name: evil),
      );

      expect(RegExp(r'window\.postMessage\(').allMatches(script).length, 1);
      final payload =
          jsonDecode(_argOf(script).substring(wootPrefix.length)) as Map;
      expect((payload['user'] as Map)['name'], evil);
    });

    test('locale and custom attributes round-trip too', () {
      final script = generateScripts(
        locale: "e'n",
        customAttributes: {'k': "v'\n\"w"},
      );
      final calls = script
          .split(');window.')
          .map((c) => c.endsWith(');') ? c : '$c);')
          .map((c) => c.startsWith('window.') ? c : 'window.$c')
          .toList();

      expect(calls.length, 2);
      expect(script, isNot(contains('\n')));
      final locale =
          jsonDecode(_argOf(calls[0]).substring(wootPrefix.length)) as Map;
      final attrs =
          jsonDecode(_argOf(calls[1]).substring(wootPrefix.length)) as Map;
      expect(locale['locale'], "e'n");
      expect((attrs['customAttributes'] as Map)['k'], "v'\n\"w");
    });

    test('nothing to inject gives an empty script', () {
      expect(generateScripts(), isEmpty);
    });
  });

  group('token scope and url (U2)', () {
    test('different users, sites and servers get different scopes', () {
      String s({String b = 'https://a', String w = 'w', String? u}) =>
          conversationTokenScope(
            baseUrl: b,
            websiteToken: w,
            userIdentifier: u,
          );

      expect(
        {s(u: 'A'), s(u: 'B'), s(), s(b: 'https://b'), s(w: 'x')}.length,
        5,
      );
      expect(s(u: 'A'), s(u: 'A'));
    });

    test('scope components cannot be forged by separators', () {
      expect(
        conversationTokenScope(
          baseUrl: 'a|b',
          websiteToken: 'c',
          userIdentifier: 'd',
        ),
        isNot(
          conversationTokenScope(
            baseUrl: 'a',
            websiteToken: 'b|c',
            userIdentifier: 'd',
          ),
        ),
      );
    });

    test('widgetUri encodes values and does not double slashes', () {
      final u = widgetUri(
        'https://chat.test/',
        websiteToken: 'a b&c',
        locale: 'en',
        token: 'T=1',
      );

      expect(u.path, '/widget');
      expect(u.queryParameters, {
        'website_token': 'a b&c',
        'locale': 'en',
        'cw_conversation': 'T=1',
      });
      expect(u.toString(), isNot(contains('//widget')));
    });

    test('widgetUri keeps a path prefix and omits an empty token', () {
      final u = widgetUri(
        'https://chat.test/cw',
        websiteToken: 'w',
        locale: 'en',
        token: '',
      );

      expect(u.path, '/cw/widget');
      expect(u.queryParameters.containsKey('cw_conversation'), isFalse);
    });
  });

  group('navigation (U14)', () {
    final widget = Uri.parse('https://chat.test/widget?website_token=w');
    NavigationVerdict d(String url, {bool main = true}) =>
        decideNavigation(widget, url, isMainFrame: main);

    test('only the widget page may stay in the main frame (SEC7)', () {
      expect(
        d('https://chat.test/widget?website_token=w&locale=en'),
        NavigationVerdict.allow,
      );
      expect(d('HTTPS://CHAT.test/widget/'), NavigationVerdict.allow);
      for (final url in [
        'https://chat.test/app/login',
        'https://chat.test/hc/portal/en',
        'https://chat.test/widgetx',
        'https://chat.test/',
      ]) {
        expect(d(url), NavigationVerdict.launchExternally, reason: url);
      }
    });

    test('web, mail and phone links open externally', () {
      for (final url in [
        'https://example.com/a',
        'http://example.com',
        'mailto:a@b.c',
        'tel:+123',
      ]) {
        expect(d(url), NavigationVerdict.launchExternally, reason: url);
      }
    });

    test(
      'another port or scheme on the same host is external, not trusted',
      () {
        expect(
          d('https://chat.test:8443/widget'),
          NavigationVerdict.launchExternally,
        );
        expect(
          d('http://chat.test/widget'),
          NavigationVerdict.launchExternally,
        );
      },
    );

    test('dangerous schemes are blocked, never launched', () {
      for (final url in [
        'intent://x#Intent;scheme=http;end',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'myapp://deep/link',
        'data:text/html,hi',
        'about:blank',
      ]) {
        expect(d(url), NavigationVerdict.block, reason: url);
      }
    });

    test('malformed or relative urls do not throw and are blocked', () {
      for (final url in [
        'http://[::1',
        ' ',
        '',
        '//no-scheme',
        'relative/path',
        '%',
      ]) {
        expect(d(url), NavigationVerdict.block, reason: url);
      }
    });

    test('subframes: https or the widget origin, the rest is blocked', () {
      expect(
        d('https://cdn.other/x.html', main: false),
        NavigationVerdict.allow,
      );
      expect(
        d('https://chat.test/anything', main: false),
        NavigationVerdict.allow,
      );
      expect(
        d('http://cdn.other/x.html', main: false),
        NavigationVerdict.block,
      );
      expect(d('mailto:a@b.c', main: false), NavigationVerdict.block);
      expect(d('intent://x', main: false), NavigationVerdict.block);
    });

    test('isWidgetPage: origin and path must both match (SEC2)', () {
      bool on(String? u) => isWidgetPage(widget, u);
      expect(on('https://chat.test/widget?x=1#f'), isTrue);
      expect(on('https://chat.test/hc/x'), isFalse);
      expect(on('https://evil.test/widget'), isFalse);
      expect(on('http://chat.test/widget'), isFalse);
      expect(on(null), isFalse);
      expect(on('::bad::'), isFalse);
    });
  });

  group('bridge messages (U15)', () {
    BridgeEvent p(String raw) => parseBridgeMessage(raw);

    test('loaded with a token', () {
      final e = p(
        '$wootPrefix{"event":"loaded","config":{"authToken":"a.b.c"}}',
      );
      expect(
        e,
        isA<BridgeLoaded>().having((e) => e.authToken, 'token', 'a.b.c'),
      );
    });

    test('the prefix is optional and only removed at the start', () {
      expect(
        p('{"event":"loaded","config":{"authToken":"a.b.c"}}'),
        isA<BridgeLoaded>(),
      );
      // the prefix is not part of the token: it fails the token shape
      final inner = jsonEncode({
        'event': 'loaded',
        'config': {'authToken': '${wootPrefix}x.y.z'},
      });
      expect(p(wootPrefix + inner), isA<BridgeIgnored>());
    });

    test('close-widget', () {
      expect(p('{"type":"close-widget"}'), isA<BridgeClose>());
    });

    test('malformed or hostile input is ignored without throwing', () {
      for (final raw in [
        '123',
        '[]',
        '"str"',
        'null',
        '',
        'not json',
        '{',
        '{"event":"loaded"}',
        '{"event":"loaded","config":null}',
        '{"event":"loaded","config":"x"}',
        '{"event":"loaded","config":{}}',
        '{"event":"loaded","config":{"authToken":""}}',
        '{"event":"loaded","config":{"authToken":5}}',
        '{"event":"loaded","config":{"authToken":"not-a-jwt"}}',
        '{"event":"loaded","config":{"authToken":"a.b"}}',
        '{"event":"loaded","config":{"authToken":"a b.c.d"}}',
        '{"event":"loaded","config":{"authToken":"${'a' * 5000}.b.c"}}',
        '{"event":"loaded","config":{"authToken":["a"]}}',
        '{"event":5}',
        '{"type":["close-widget"]}',
        '{"event":"other"}',
      ]) {
        expect(p(raw), isA<BridgeIgnored>(), reason: raw);
      }
    });
  });
}
