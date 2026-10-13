/// Hosts for which plain http is acceptable: the local machine and the Android
/// emulator's alias for it.
const _loopbackHosts = {'localhost', '127.0.0.1', '::1', '10.0.2.2'};

/// Parses and validates the base URL of a Chatwoot server.
///
/// Requires `https`. Plain `http` is only accepted for loopback hosts
/// (`localhost`, `127.0.0.1`, `::1`, `10.0.2.2`) or when [allowInsecure] is
/// true. Throws [ArgumentError] otherwise.
Uri validateBaseUrl(String url, {bool allowInsecure = false}) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) {
    throw ArgumentError.value(url, 'baseUrl', 'must be an absolute URL');
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
