import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zukko_chat_flutter/src/ui/chat/components/components.dart';
import 'package:zukko_chat_flutter/src/ui/chat/zukko_chat_style.dart';
import 'package:zukko_chat_flutter/src/ui/theme/zukko_chat_theme.dart';

import '../styles/styles_harness.dart';

const _html = '''
<html><head><title>Fallback &amp; title</title>
<meta property="og:title" content="OG Title">
<meta content='A &quot;nice&quot; page' property='og:description'>
<meta property="og:image" content="/pic.png">
</head></html>''';

class _Adapter implements HttpClientAdapter {
  final List<int> body;
  final String type;
  final Duration delay;
  Uri? redirectedTo;
  int calls = 0;
  _Adapter(String text, {this.type = 'text/html', this.delay = Duration.zero})
    : body = utf8.encode(text);
  _Adapter.bytes(this.body) : type = 'text/html', delay = Duration.zero;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    await Future<void>.delayed(delay);
    final to = redirectedTo;
    return ResponseBody(
      Stream.value(Uint8List.fromList(body)),
      200,
      isRedirect: to != null,
      redirects: [if (to != null) RedirectRecord(302, 'GET', to)],
      headers: {
        Headers.contentTypeHeader: [type],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adapter a) => Dio()..httpClientAdapter = a;

void main() {
  group('findLinks', () {
    test('first http(s) link only, other schemes ignored', () {
      final links = findLinks(
        'mail mailto:a@b.c js javascript:alert(1) ftp://x.y '
        'see https://one.test/a, then http://two.test',
      );
      expect(links.first.uri.toString(), 'https://one.test/a');
      expect(links.map((l) => l.uri.scheme), everyElement(startsWith('http')));
      expect(findLinks('ftp://x.y mailto:a@b.c javascript:1'), isEmpty);
    });
  });

  group('parseLinkPreview', () {
    final base = Uri.parse('https://site.test/page');
    test('og tags win, relative image resolved, entities decoded', () {
      final d = parseLinkPreview(_html, base)!;
      expect(d.title, 'OG Title');
      expect(d.description, 'A "nice" page');
      expect(d.image!.url, 'https://site.test/pic.png');
    });
    test('falls back to <title>; missing tags -> null', () {
      expect(
        parseLinkPreview('<title> Only  title </title>', base)!.title,
        'Only title',
      );
      expect(parseLinkPreview('<html></html>', base), isNull);
    });
    test('hostile entities and long emoji titles do not break parsing', () {
      final d = parseLinkPreview(
        '<meta property="og:title" content="a&#99999999999;b&#xD800;c&#0;d">'
        '<meta property="og:description" content="${'x' * 299}😀tail">',
        base,
      )!;
      expect(d.title, 'a b c d');
      // The emoji straddles the cap: it is dropped whole, not cut in half.
      expect(d.description, '${'x' * 299}...');
    });
    test('http image is dropped', () {
      final d = parseLinkPreview(
        '<meta property="og:title" content="T">'
        '<meta property="og:image" content="http://x.test/a.png">',
        base,
      )!;
      expect(d.image, isNull);
    });
  });

  group('fetchLinkPreview', () {
    final uri = Uri.parse('https://site.test/');
    test('parses a page', () async {
      final d = await fetchLinkPreview(uri, client: _dio(_Adapter(_html)));
      expect(d?.title, 'OG Title');
    });
    test('a relative og:image resolves against the final URL', () async {
      final a = _Adapter('<meta property="og:image" content="/pic.png">')
        ..redirectedTo = Uri.parse('https://final.test/x/');
      final d = await fetchLinkPreview(uri, client: _dio(a));
      expect(d?.image?.url, 'https://final.test/pic.png');
      expect(d?.link, '$uri');
    });
    test('non-http scheme is never fetched', () async {
      final a = _Adapter(_html);
      expect(
        await fetchLinkPreview(Uri.parse('ftp://x.test'), client: _dio(a)),
        isNull,
      );
      expect(a.calls, 0);
    });
    test('non-html content -> null', () async {
      final a = _Adapter(_html, type: 'application/pdf');
      expect(await fetchLinkPreview(uri, client: _dio(a)), isNull);
    });
    test('only the first 512 KB are read', () async {
      final filler = List.filled(linkPreviewMaxBytes + 10, 32);
      final late = utf8.encode('<meta property="og:title" content="Late">');
      final a = _Adapter.bytes([...filler, ...late]);
      expect(await fetchLinkPreview(uri, client: _dio(a)), isNull);
    });
    test('timeout -> null', () {
      Future<LinkPreviewData?> fakeAsyncTimeout() async {
        final a = _Adapter(_html, delay: linkPreviewTimeout * 2);
        return fetchLinkPreview(uri, client: _dio(a));
      }

      expect(fakeAsyncTimeout(), completion(isNull));
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('LinkPreviewService', () {
    final uri = Uri.parse('https://site.test/');
    LinkPreviewData data(String t) => LinkPreviewData(link: '$uri', title: t);

    test('concurrent loads share one fetch; result cached', () async {
      var calls = 0;
      final gate = Completer<LinkPreviewData?>();
      final s = LinkPreviewService(
        fetcher: (u) {
          calls++;
          return gate.future;
        },
      );
      final a = s.load(uri), b = s.load(uri);
      gate.complete(data('T'));
      expect((await a)?.title, 'T');
      expect((await b)?.title, 'T');
      await s.load(uri);
      expect(calls, 1);
    });
    test('failure is cached: no retry', () async {
      var calls = 0;
      final s = LinkPreviewService(
        fetcher: (u) async {
          calls++;
          throw StateError('x');
        },
      );
      expect(await s.load(uri), isNull);
      expect(await s.load(uri), isNull);
      expect(calls, 1);
    });
    test('LRU is bounded', () async {
      final s = LinkPreviewService(
        fetcher: (u) async => data('$u'),
        capacity: 2,
      );
      for (final i in [1, 2, 3]) {
        await s.load(Uri.parse('https://s.test/$i'));
      }
      expect(s.isCached(Uri.parse('https://s.test/1')), isFalse);
      expect(s.isCached(Uri.parse('https://s.test/3')), isTrue);
    });
    test('non-http uri is not fetched', () async {
      var calls = 0;
      final s = LinkPreviewService(
        fetcher: (u) async {
          calls++;
          return null;
        },
      );
      await s.load(Uri.parse('ftp://x.test'));
      expect(calls, 0);
    });
  });

  group('bubbles', () {
    final link = Uri.parse('https://zukko.ai/docs');
    Widget host(Widget child, LinkPreviewService? s) => MaterialApp(
      home: Scaffold(
        body: LinkPreviewScope(service: s, child: child),
      ),
    );

    for (final kind in ZukkoChatStyle.values) {
      testWidgets('${kind.name}: card shows the fetched title', (tester) async {
        final calls = <Uri>[];
        final s = LinkPreviewService(
          fetcher: (u) async {
            calls.add(u);
            return LinkPreviewData(link: '$u', title: 'Zukko Docs');
          },
        );
        final b = kind
            .resolve(const ZukkoChatTheme(brightness: Brightness.light))
            .messageBuilders(chatEnv());
        // Two bubbles with the same link: one fetch.
        await tester.pumpWidget(
          host(
            Column(
              children: [
                messageOf(b, sampleMessages().first, false),
                messageOf(b, sampleMessages().first, true),
              ],
            ),
            s,
          ),
        );
        expect(find.text('Zukko Docs'), findsNothing);
        await tester.pumpAndSettle();
        expect(find.text('Zukko Docs'), findsNWidgets(2));
        expect(calls, [link]);
        expect(find.bySemanticsLabel('Zukko Docs, zukko.ai'), findsNWidgets(2));
        expect(
          tester.getSize(find.byType(LinkPreviewCard).first).height,
          greaterThanOrEqualTo(48),
        );
      });

      testWidgets('${kind.name}: no service -> no fetch, domain card', (
        tester,
      ) async {
        final b = kind
            .resolve(const ZukkoChatTheme(brightness: Brightness.light))
            .messageBuilders(chatEnv());
        await tester.pumpWidget(
          host(messageOf(b, sampleMessages().first, false), null),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LinkPreviewCard), findsOneWidget);
        expect(find.text('zukko.ai'), findsOneWidget);
      });
    }
  });
}
