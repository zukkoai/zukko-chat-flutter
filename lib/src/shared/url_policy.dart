/// Hosts for which plain http is acceptable: the local machine and the Android
/// emulator's alias for it.
const _loopbackHosts = {'localhost', '127.0.0.1', '::1', '10.0.2.2'};

/// Parses and validates the base URL of a ZukkoChat server. The URL is trimmed:
/// use the returned [Uri] (not the raw string) everywhere afterwards.
///
/// Requires `https`. Plain `http` is only accepted for loopback hosts
/// (`localhost`, `127.0.0.1`, `::1`, `10.0.2.2`) or when [allowInsecure] is
/// true. User info (`https://user:pw@host`) and fragments are rejected: the
/// base URL ends up in persisted keys and logs. Throws [ArgumentError]
/// otherwise.
Uri validateBaseUrl(String url, {bool allowInsecure = false}) {
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
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return uri;
  if (scheme == 'http' &&
      (allowInsecure || _loopbackHosts.contains(uri.host.toLowerCase()))) {
    return uri;
  }
  throw ArgumentError.value(
    url,
    'baseUrl',
    'must use https (http is only allowed for localhost or with allowInsecure)',
  );
}

/// `ws(s)://host[/prefix]/cable` for a REST [base] already checked by
/// [validateBaseUrl] (so its scheme is http or https).
Uri zukkoChatCableUri(Uri base) {
  final segments = base.pathSegments.where((s) => s.isNotEmpty).toList();
  return base.replace(
    scheme: base.scheme.toLowerCase() == 'https' ? 'wss' : 'ws',
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
