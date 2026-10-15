import 'dart:convert';

/// Identifies one client instance (server + inbox + user) in local storage.
///
/// Components are escaped so the `|||` separator can never appear inside one,
/// and a missing user identifier is an empty segment (distinct from a real
/// user called "null").
///
/// When the user comes with an [identifierHash], a short stable digest of it is
/// appended, so the same identifier with another hash never reuses a stored
/// contact. Without a hash the key is unchanged (keys of earlier versions).
String chatwootInstanceKey({
  required String baseUrl,
  required String websiteToken,
  String? userIdentifier,
  String? identifierHash,
}) {
  final base =
      '${_escape(baseUrl)}$_sep${_escape(userIdentifier ?? '')}$_sep${_escape(websiteToken)}';
  return identifierHash == null || identifierHash.isEmpty
      ? base
      : '$base${_sep}h:${_digest(identifierHash)}';
}

/// FNV-1a (64 bit) of [value] as 16 lowercase hex chars. Not a security
/// primitive: it only keeps the raw hash out of the key and makes keys differ
/// per hash. BigInt keeps the result identical on the VM and on web.
String _digest(String value) {
  final mask = (BigInt.one << 64) - BigInt.one;
  final prime = BigInt.from(0x100000001b3);
  var h = BigInt.parse('cbf29ce484222325', radix: 16);
  for (final byte in utf8.encode(value)) {
    h = ((h ^ BigInt.from(byte)) * prime) & mask;
  }
  return h.toRadixString(16).padLeft(16, '0');
}

const _sep = '|||';

/// Whether [key] has the shape of [chatwootInstanceKey] (also matches the
/// per-message keys derived from it).
bool isInstanceKey(String key) => key.split(_sep).length >= 3;

String _escape(String v) => v.replaceAll('%', '%25').replaceAll('|', '%7C');

/// Converts a key written by SDK versions <= 0.0.9 (`base|||user|||inbox`, with
/// the literal "null" for no user) to the current format. Returns `null` when
/// the legacy key cannot be parsed unambiguously.
String? chatwootInstanceKeyFromLegacy(String legacy) {
  final parts = legacy.split(_sep);
  if (parts.length != 3) return null;
  return chatwootInstanceKey(
    baseUrl: parts[0],
    userIdentifier: parts[1] == 'null' ? null : parts[1],
    websiteToken: parts[2],
  );
}
