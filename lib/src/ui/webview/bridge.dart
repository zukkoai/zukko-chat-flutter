import 'dart:convert';

import '../../data/models/chatwoot_user.dart';

/// Pure helpers for talking to the Chatwoot web widget (no Flutter, no I/O).

const wootPrefix = 'chatwoot-widget:';

/// JS that delivers [object] to the widget via `window.postMessage`.
///
/// The payload is JSON inside a JS string literal; the literal is produced by
/// `jsonEncode`, so quotes, apostrophes, newlines and backslashes in user data
/// can neither end the string nor corrupt the inner JSON.
String createWootPostMessage(Object? object) =>
    'window.postMessage(${jsonEncode('$wootPrefix${jsonEncode(object)}')});';

/// The scripts run once the widget reports `loaded`.
String generateScripts({
  ChatwootUser? user,
  String? locale,
  Object? customAttributes,
}) {
  final script = StringBuffer();
  if (user != null) {
    script.write(
      createWootPostMessage({
        'event': 'set-user',
        'identifier': user.identifier,
        'user': user,
      }),
    );
  }
  if (locale != null) {
    script.write(
      createWootPostMessage({'event': 'set-locale', 'locale': locale}),
    );
  }
  if (customAttributes != null) {
    script.write(
      createWootPostMessage({
        'event': 'set-custom-attributes',
        'customAttributes': customAttributes,
      }),
    );
  }
  return script.toString();
}

/// `<baseUrl>/widget?website_token=..&locale=..[&cw_conversation=..]`
/// with proper encoding and no doubled slash.
Uri widgetUri(
  String baseUrl, {
  required String websiteToken,
  required String locale,
  String? token,
}) {
  final base = Uri.parse(baseUrl);
  return base.replace(
    pathSegments: [...base.pathSegments.where((s) => s.isNotEmpty), 'widget'],
    queryParameters: {
      'website_token': websiteToken,
      'locale': locale,
      if (token != null && token.isNotEmpty) 'cw_conversation': token,
    },
  );
}

/// Key under which a conversation token is stored: one per server, website
/// and user so that one user can never open another user's conversation.
String conversationTokenScope({
  required String baseUrl,
  required String websiteToken,
  String? userIdentifier,
}) =>
    'chatwoot_conversation:${jsonEncode([baseUrl, websiteToken, userIdentifier ?? ''])}';

enum NavigationVerdict {
  /// Let the webview load it.
  allow,

  /// Cancel and hand the URL to the OS (browser, mail, phone).
  launchExternally,

  /// Cancel and do nothing.
  block,
}

const _externalSchemes = {'http', 'https', 'mailto', 'tel'};

bool _sameOrigin(Uri a, Uri b) =>
    a.scheme.toLowerCase() == b.scheme.toLowerCase() &&
    a.host.toLowerCase() == b.host.toLowerCase() &&
    a.port == b.port;

String _trimSlash(String path) =>
    path.endsWith('/') ? path.substring(0, path.length - 1) : path;

/// True when [current] is the widget page itself (origin and path of
/// [widgetUrl]). Gate for everything the page may ask of us or receive.
bool isWidgetPage(Uri widgetUrl, String? current) {
  final uri = current == null ? null : Uri.tryParse(current);
  return uri != null &&
      _sameOrigin(widgetUrl, uri) &&
      _trimSlash(uri.path) == _trimSlash(widgetUrl.path);
}

/// Decides what to do with a navigation inside the widget. Never throws.
///
/// The main frame may only stay on the widget page; every other http(s) URL
/// (also on the same origin, e.g. a dashboard login) opens in the OS browser.
/// Subframes are limited to the widget origin and https.
NavigationVerdict decideNavigation(
  Uri widgetUrl,
  String url, {
  bool isMainFrame = true,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return NavigationVerdict.block;
  final scheme = uri.scheme.toLowerCase();
  if (!isMainFrame) {
    return _sameOrigin(widgetUrl, uri) || scheme == 'https'
        ? NavigationVerdict.allow
        : NavigationVerdict.block;
  }
  if (isWidgetPage(widgetUrl, url)) return NavigationVerdict.allow;
  return _externalSchemes.contains(scheme)
      ? NavigationVerdict.launchExternally
      : NavigationVerdict.block;
}

sealed class BridgeEvent {
  const BridgeEvent();
}

/// The widget finished loading and reports its auth token.
class BridgeLoaded extends BridgeEvent {
  final String authToken;
  const BridgeLoaded(this.authToken);
}

class BridgeClose extends BridgeEvent {
  const BridgeClose();
}

class BridgeIgnored extends BridgeEvent {
  const BridgeIgnored();
}

/// Conversation tokens are JWTs: three base64url parts, bounded length.
final _tokenShape = RegExp(r'^(?=.{1,4096}$)[\w-]+\.[\w-]+\.[\w-]+$');

/// Parses one message from the page. The page is untrusted: anything that is
/// not exactly the expected shape is [BridgeIgnored].
BridgeEvent parseBridgeMessage(String raw) {
  final body = raw.startsWith(wootPrefix)
      ? raw.substring(wootPrefix.length)
      : raw;
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return const BridgeIgnored();
  }
  if (decoded is! Map) return const BridgeIgnored();
  if (decoded['event'] == 'loaded') {
    final config = decoded['config'];
    final token = config is Map ? config['authToken'] : null;
    return token is String && _tokenShape.hasMatch(token)
        ? BridgeLoaded(token)
        : const BridgeIgnored();
  }
  if (decoded['type'] == 'close-widget') return const BridgeClose();
  return const BridgeIgnored();
}
