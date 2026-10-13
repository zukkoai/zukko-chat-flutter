import 'dart:async';

import 'package:chatwoot_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_sdk/src/ui/webview/bridge.dart';
import 'package:chatwoot_sdk/src/ui/webview/token_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'fake_webview_platform.dart';

const _base = 'https://x.test';
const _jwt = 'aaa.bbb.ccc';

String _loaded([String token = _jwt]) =>
    '{"event":"loaded","config":{"authToken":"$token"}}';

String _scope(String site, {String? user, String base = _base}) =>
    conversationTokenScope(
      baseUrl: base,
      websiteToken: site,
      userIdentifier: user,
    );

class _Store implements ChatwootTokenStore {
  _Store([Map<String, String>? values]) : values = values ?? {};
  final Map<String, String> values;
  final writes = <(String, String)>[];
  final deleted = <String>[];
  Completer<void>? readGate;

  @override
  Future<String?> read(String scope) async {
    await readGate?.future;
    return values[scope];
  }

  @override
  Future<void> write(String scope, String token) async {
    writes.add((scope, token));
    values[scope] = token;
  }

  @override
  Future<void> delete(String scope) async {
    deleted.add(scope);
    values.remove(scope);
  }
}

Widget _host({
  String site = 'w',
  String baseUrl = _base,
  ChatwootUser? user,
  String locale = 'en',
  Object? customAttributes,
  ChatwootTokenStore? store,
  VoidCallback? onClose,
  void Function(String)? onError,
  bool allowInsecure = false,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: ChatwootWidget(
    websiteToken: site,
    baseUrl: baseUrl,
    user: user,
    locale: locale,
    customAttributes: customAttributes,
    tokenStore: store ?? _Store(),
    closeWidget: onClose,
    onError: onError,
    allowInsecure: allowInsecure,
  ),
);

/// Lets the widget's chain of already-completed futures run.
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeWebViewPlatform platform;

  setUp(() => platform = FakeWebViewPlatform.install());

  group('loading', () {
    testWidgets('loads /widget with token, locale and unrestricted JS', (
      tester,
    ) async {
      final store = _Store({_scope('w'): 'old.tok.en'});
      await tester.pumpWidget(_host(store: store, locale: 'fr'));
      await _flush(tester);

      final c = platform.controllers.single;
      expect(c.loads.single.path, '/widget');
      expect(c.loads.single.queryParameters, {
        'website_token': 'w',
        'locale': 'fr',
        'cw_conversation': 'old.tok.en',
      });
      expect(c.javaScriptMode, JavaScriptMode.unrestricted);
      expect(find.byKey(const Key('webview')), findsOneWidget);
    });

    testWidgets('removed before the token is read: nothing is built (U16)', (
      tester,
    ) async {
      final store = _Store()..readGate = Completer<void>();
      await tester.pumpWidget(_host(store: store));
      await tester.pumpWidget(const SizedBox());
      store.readGate!.complete();
      await _flush(tester);

      expect(platform.controllers, isEmpty);
    });

    testWidgets('a load superseded by a target change is discarded (U16)', (
      tester,
    ) async {
      final slow = _Store()..readGate = Completer<void>();
      await tester.pumpWidget(_host(site: 'a', store: slow));
      await tester.pumpWidget(_host(site: 'b', store: _Store()));
      await _flush(tester);
      slow.readGate!.complete();
      await _flush(tester);

      expect(platform.controllers.single.loads.single.queryParameters, {
        'website_token': 'b',
        'locale': 'en',
      });
    });

    testWidgets('http base url is refused without allowInsecure (SEC4)', (
      tester,
    ) async {
      final errors = <String>[];
      await tester.pumpWidget(
        _host(baseUrl: 'http://example.com', onError: errors.add),
      );
      await _flush(tester);

      expect(platform.controllers, isEmpty);
      expect(errors, hasLength(1));
    });

    testWidgets('http is loaded with allowInsecure, and on loopback (SEC4)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(baseUrl: 'http://example.com', allowInsecure: true),
      );
      await _flush(tester);
      expect(platform.controllers.single.loads.single.scheme, 'http');

      await tester.pumpWidget(const SizedBox());
      platform.controllers.clear();
      await tester.pumpWidget(_host(baseUrl: 'http://localhost:3000'));
      await _flush(tester);
      expect(platform.controllers.single.loads, hasLength(1));
    });
  });

  group('bridge messages (SEC2)', () {
    testWidgets('loaded on the widget page stores the token and injects once', (
      tester,
    ) async {
      final store = _Store();
      await tester.pumpWidget(
        _host(
          store: store,
          user: ChatwootUser(identifier: 'u', name: 'N'),
        ),
      );
      await _flush(tester);
      final c = platform.controllers.single;

      c.post(_loaded());
      c.post(_loaded('ddd.eee.fff')); // a second `loaded` in the same load
      await _flush(tester);

      expect(store.writes, [(_scope('w', user: 'u'), _jwt)]);
      expect(c.scripts, hasLength(1));
      expect(c.scripts.single, contains('set-user'));
      expect(c.scripts.single, contains('set-locale'));
    });

    testWidgets('loaded while another page is shown: no write, no script', (
      tester,
    ) async {
      final store = _Store();
      await tester.pumpWidget(
        _host(
          store: store,
          user: ChatwootUser(identifier: 'u'),
        ),
      );
      await _flush(tester);
      final c = platform.controllers.single..url = '$_base/hc/some-article';

      c.post(_loaded());
      await _flush(tester);

      expect(store.writes, isEmpty);
      expect(c.scripts, isEmpty);
    });

    testWidgets('a spoof does not use up the one loaded of the real page', (
      tester,
    ) async {
      final store = _Store();
      await tester.pumpWidget(_host(store: store));
      await _flush(tester);
      final c = platform.controllers.single;
      final widgetUrl = c.url;

      c.url = 'https://evil.test/';
      c.post(_loaded('bad.tok.en'));
      await _flush(tester);
      c.url = widgetUrl;
      c.post(_loaded());
      await _flush(tester);

      expect(store.writes.single.$2, _jwt);
    });

    testWidgets('malformed or oversized tokens are ignored', (tester) async {
      final store = _Store();
      await tester.pumpWidget(_host(store: store));
      await _flush(tester);
      final c = platform.controllers.single;

      c.post(_loaded('not a jwt'));
      c.post(_loaded('${'a' * 5000}.b.c'));
      await _flush(tester);

      expect(store.writes, isEmpty);
      expect(c.scripts, isEmpty);
    });

    testWidgets('close-widget works on the widget page only', (tester) async {
      var closed = 0;
      await tester.pumpWidget(_host(onClose: () => closed++));
      await _flush(tester);
      final c = platform.controllers.single;
      final widgetUrl = c.url;

      c.post('{"type":"close-widget"}');
      await _flush(tester);
      expect(closed, 1);

      c.url = 'https://evil.test/';
      c.post('{"type":"close-widget"}');
      await _flush(tester);
      expect(closed, 1);
      c.url = widgetUrl;
    });
  });

  group('switching target (F4, SEC1)', () {
    testWidgets('loaded from the previous webview is ignored (F4)', (
      tester,
    ) async {
      final store = _Store();
      await tester.pumpWidget(
        _host(
          store: store,
          user: ChatwootUser(identifier: 'a'),
        ),
      );
      await _flush(tester);
      final old = platform.controllers.single;

      await tester.pumpWidget(
        _host(
          store: store,
          user: ChatwootUser(identifier: 'b'),
        ),
      );
      await _flush(tester);
      old.post(_loaded('aaa.aaa.aaa'));
      await _flush(tester);

      expect(store.writes, isEmpty); // not under A, and above all not under B
      expect(old.scripts, isEmpty);

      platform.controllers.last.post(_loaded('bbb.bbb.bbb'));
      await _flush(tester);
      expect(store.writes, [(_scope('w', user: 'b'), 'bbb.bbb.bbb')]);
    });

    testWidgets('web data is wiped before the next user loads (SEC1)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(user: ChatwootUser(identifier: 'a')));
      await _flush(tester);
      expect(platform.log, isNot(contains('clearCookies'))); // first load

      platform.log.clear();
      await tester.pumpWidget(_host(user: ChatwootUser(identifier: 'b')));
      await _flush(tester);

      final loadAt = platform.log.indexWhere((e) => e.startsWith('load'));
      expect(loadAt, greaterThan(-1));
      expect(platform.log.sublist(0, loadAt), [
        'clearCookies',
        'clearStorage',
        'clearCache',
      ]);
    });

    testWidgets('same target and a new locale re-injects, no reload', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await _flush(tester);
      final c = platform.controllers.single;

      await tester.pumpWidget(_host(locale: 'de'));
      await _flush(tester);

      expect(platform.controllers, hasLength(1));
      expect(c.scripts.single, contains(r'\"locale\":\"de\"'));
      expect(platform.cookieClears, 0);
    });
  });

  group('sign-out (SEC1)', () {
    test('clearStoredConversation deletes the scoped token', () async {
      final store = _Store();
      await ChatwootWidget.clearStoredConversation(
        baseUrl: _base,
        websiteToken: 'w',
        user: ChatwootUser(identifier: 'u'),
        tokenStore: store,
      );
      await ChatwootWidget.clearStoredConversation(
        baseUrl: _base,
        websiteToken: 'w',
        tokenStore: store,
      );

      expect(store.deleted, hasLength(2));
      expect(store.deleted.toSet(), hasLength(2));
    });

    test('and wipes cookies, local storage and cache', () async {
      await ChatwootWidget.clearStoredConversation(
        baseUrl: _base,
        websiteToken: 'w',
        tokenStore: _Store(),
      );

      expect(platform.log, ['clearCookies', 'clearStorage', 'clearCache']);
    });
  });

  group('navigation (SEC7)', () {
    testWidgets('widget stays, dashboard and external pages leave', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await _flush(tester);
      final c = platform.controllers.single;

      expect(
        await c.request('$_base/widget?website_token=w'),
        NavigationDecision.navigate,
      );
      expect(await c.request('$_base/app/login'), NavigationDecision.prevent);
      expect(await c.request('https://o.test/'), NavigationDecision.prevent);
      expect(
        await c.request('javascript:alert(1)'),
        NavigationDecision.prevent,
      );
      expect(
        await c.request('http://o.test/f', isMainFrame: false),
        NavigationDecision.prevent,
      );
      expect(
        await c.request('https://o.test/f', isMainFrame: false),
        NavigationDecision.navigate,
      );
    });
  });

  group('parameters (SEC10)', () {
    testWidgets('non-JSON customAttributes go to onError, no script', (
      tester,
    ) async {
      final errors = <String>[];
      await tester.pumpWidget(
        _host(customAttributes: Object(), onError: errors.add),
      );
      await _flush(tester);
      final c = platform.controllers.single;

      c.post(_loaded());
      await _flush(tester);

      expect(errors, hasLength(1));
      expect(c.scripts, isEmpty);
    });
  });

  test(
    'the default token store keeps the iOS keychain item on this device (SEC5)',
    () {
      expect(
        SecureTokenStore.defaultStorage.iOptions.accessibility,
        KeychainAccessibility.first_unlock_this_device,
      );
    },
  );
}
