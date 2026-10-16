import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show ImagePreviewData, LinkPreviewData;

import '../../../shared/sdk_log.dart';
import '../../../shared/url_policy.dart';

/// Loads the preview of [uri]; null when there is none. Must not throw.
typedef LinkPreviewFetcher = Future<LinkPreviewData?> Function(Uri uri);

/// At most this many bytes of a page are read (the head is enough).
const linkPreviewMaxBytes = 512 * 1024;

/// Whole-request time limit.
const linkPreviewTimeout = Duration(seconds: 5);

/// Session cache + de-duplication in front of a [LinkPreviewFetcher].
/// Failures are cached too (as null), so a dead link is asked for only once.
class LinkPreviewService {
  final LinkPreviewFetcher _fetch;
  final int capacity;
  final _cache = <String, LinkPreviewData?>{};
  final _inflight = <String, Future<LinkPreviewData?>>{};

  LinkPreviewService({LinkPreviewFetcher? fetcher, this.capacity = 100})
    : _fetch = fetcher ?? fetchLinkPreview;

  bool isCached(Uri uri) => _cache.containsKey('$uri');

  /// The cached preview of [uri] (null when unknown or failed).
  LinkPreviewData? cached(Uri uri) => _cache['$uri'];

  /// Preview of [uri]: cached, joined to a running request, or fetched.
  Future<LinkPreviewData?> load(Uri uri) {
    final key = '$uri';
    if (!isHttpUrl(key)) return Future.value();
    if (_cache.containsKey(key)) {
      final hit = _cache.remove(key); // re-insert: most recently used last
      _cache[key] = hit;
      return Future.value(hit);
    }
    final existing = _inflight[key];
    if (existing != null) return existing;
    return _inflight[key] = _run(uri, key);
  }

  Future<LinkPreviewData?> _run(Uri uri, String key) async {
    LinkPreviewData? data;
    try {
      data = await _fetch(uri);
    } catch (e) {
      sdkLog(
        'link preview failed: ${e.runtimeType}',
        level: SdkLogLevel.warning,
      );
    }
    unawaited(_inflight.remove(key));
    _cache[key] = data;
    if (_cache.length > capacity) _cache.remove(_cache.keys.first);
    return data;
  }
}

/// Provides the [LinkPreviewService] to the bubbles below; [service] null
/// turns previews off (no fetch).
class LinkPreviewScope extends InheritedWidget {
  final LinkPreviewService? service;

  const LinkPreviewScope({
    super.key,
    required this.service,
    required super.child,
  });

  static LinkPreviewService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LinkPreviewScope>()?.service;

  @override
  bool updateShouldNotify(LinkPreviewScope old) => service != old.service;
}

// A plain client: nothing of the SDK's (auth headers) goes to third parties.
Dio _plainClient() => Dio(
  BaseOptions(
    connectTimeout: linkPreviewTimeout,
    receiveTimeout: linkPreviewTimeout,
    maxRedirects: 3,
    headers: {
      'Accept': 'text/html,application/xhtml+xml',
      'User-Agent': 'Mozilla/5.0 (compatible; ZukkoChat link preview)',
    },
  ),
);

/// Default fetcher: GET [uri] with a plain Dio, first [linkPreviewMaxBytes]
/// of the HTML, parsed with [parseLinkPreview]. Null on any failure.
Future<LinkPreviewData?> fetchLinkPreview(Uri uri, {Dio? client}) async {
  if (!isHttpUrl('$uri')) return null;
  final dio = client ?? _plainClient();
  final cancel = CancelToken();
  try {
    return await Future(() async {
      final res = await dio.getUri<ResponseBody>(
        uri,
        cancelToken: cancel,
        options: Options(responseType: ResponseType.stream),
      );
      final type = res.headers.value(Headers.contentTypeHeader) ?? '';
      if (type.isNotEmpty && !type.toLowerCase().contains('html')) return null;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in res.data!.stream) {
        bytes.add(chunk);
        if (bytes.length >= linkPreviewMaxBytes) break;
      }
      final all = bytes.takeBytes();
      final head = all.length > linkPreviewMaxBytes
          ? all.sublist(0, linkPreviewMaxBytes)
          : all;
      return parseLinkPreview(
        utf8.decode(head, allowMalformed: true),
        uri,
        resolveAgainst: res.realUri,
      );
    }).timeout(linkPreviewTimeout);
  } catch (_) {
    return null;
  } finally {
    cancel.cancel();
    if (client == null) dio.close(force: true);
  }
}

final _metaTag = RegExp(r'<meta\s[^>]*>', caseSensitive: false);
final _attr = RegExp(r'''([a-zA-Z:_-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')''');
final _titleTag = RegExp(
  r'<title[^>]*>(.*?)</title>',
  caseSensitive: false,
  dotAll: true,
);

/// Open Graph title / description / image of [html] (falls back to `<title>`
/// and `<meta name="description">`); null when nothing usable. The image must
/// be https.
LinkPreviewData? parseLinkPreview(
  String html,
  Uri base, {
  Uri? resolveAgainst,
}) {
  final meta = <String, String>{};
  for (final tag in _metaTag.allMatches(html)) {
    final attrs = <String, String>{};
    for (final a in _attr.allMatches(tag.group(0)!)) {
      attrs[a.group(1)!.toLowerCase()] = a.group(2) ?? a.group(3) ?? '';
    }
    final key = (attrs['property'] ?? attrs['name'])?.toLowerCase();
    final content = attrs['content'];
    if (key != null && content != null) meta.putIfAbsent(key, () => content);
  }
  String? clean(String? s, int max) {
    final t = s == null
        ? ''
        : _decodeEntities(s).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return null;
    if (t.length <= max) return t;
    // Do not cut a surrogate pair (emoji) in half.
    final cut =
        t.codeUnitAt(max - 1) >= 0xD800 && t.codeUnitAt(max - 1) < 0xDC00
        ? max - 1
        : max;
    return '${t.substring(0, cut)}...';
  }

  final title =
      clean(meta['og:title'], 200) ??
      clean(meta['twitter:title'], 200) ??
      clean(_titleTag.firstMatch(html)?.group(1), 200);
  final description =
      clean(meta['og:description'], 300) ??
      clean(meta['twitter:description'], 300) ??
      clean(meta['description'], 300);

  ImagePreviewData? image;
  final rawImage = meta['og:image'] ?? meta['og:image:url'];
  if (rawImage != null && rawImage.trim().isNotEmpty) {
    final resolved = (resolveAgainst ?? base).resolve(
      _decodeEntities(rawImage.trim()),
    );
    if (isHttpsUrl('$resolved')) {
      image = ImagePreviewData(
        url: '$resolved',
        width: double.tryParse(meta['og:image:width'] ?? '') ?? 0,
        height: double.tryParse(meta['og:image:height'] ?? '') ?? 0,
      );
    }
  }
  if (title == null && description == null && image == null) return null;
  return LinkPreviewData(
    link: '$base',
    title: title,
    description: description,
    image: image,
  );
}

String _decodeEntities(String s) => s.replaceAllMapped(
  RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos|nbsp);'),
  (m) {
    final e = m.group(1)!;
    if (e.startsWith('#')) {
      final hex = e.startsWith('#x');
      final code = int.tryParse(e.substring(hex ? 2 : 1), radix: hex ? 16 : 10);
      // Hostile pages: out of range, NUL or a lone surrogate would throw.
      final valid =
          code != null &&
          code > 0 &&
          code <= 0x10FFFF &&
          !(code >= 0xD800 && code <= 0xDFFF);
      return valid ? String.fromCharCode(code) : ' ';
    }
    return switch (e) {
      'amp' => '&',
      'lt' => '<',
      'gt' => '>',
      'quot' => '"',
      'apos' => "'",
      _ => ' ',
    };
  },
);
