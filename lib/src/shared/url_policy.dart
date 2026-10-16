/// Parses and validates the base URL of a ZukkoChat server. The URL is trimmed:
/// use the returned [Uri] (not the raw string) everywhere afterwards.
///
/// Requires `https`; plain `http` is always rejected (also for localhost). User info (`https://user:pw@host`) and fragments are rejected: the
/// base URL ends up in persisted keys and logs. Throws [ArgumentError]
/// otherwise.
Uri validateBaseUrl(String url, ) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) {
    throw ArgumentError.value(url, 'baseUrl', 'must be an absolute URL');
  }
  if (uri.userInfo.isNotEmpty || uri.hasFragment) {
    throw ArgumentError.value(
      url,
      'baseUrl',
      'must not contain user info or a fragment',
    );
  }
  if (uri.scheme.toLowerCase() == 'https') return uri;
  throw ArgumentError.value(url, 'baseUrl', 'must use https');
}

/// `ws(s)://host[/prefix]/cable` for a REST [base] already checked by
/// [validateBaseUrl] (so its scheme is https).
Uri zukkoChatCableUri(Uri base) {
  final segments = base.pathSegments.where((s) => s.isNotEmpty).toList();
  return base.replace(
    scheme: 'wss',
    pathSegments: [...segments, 'cable'],
  );
}

/// Whether [url] has an `http` or `https` scheme (case-insensitive).
bool isHttpUrl(String? url) {
  final scheme = url == null ? null : Uri.tryParse(url)?.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

/// Whether [url] has an `https` scheme (case-insensitive).
bool isHttpsUrl(String? url) {
  final scheme = url == null ? null : Uri.tryParse(url)?.scheme.toLowerCase();
  return scheme == 'https';
}

/// An avatar URL that came from the server or the app, or null when it must
/// not be loaded: only https, and not the `?d=404` placeholder the server uses
/// for "no picture".
String? safeAvatarUrl(String? url) =>
    isHttpsUrl(url) && !url!.contains('?d=404') ? url : null;
