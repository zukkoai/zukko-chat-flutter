# Certificate / SSL pinning in Dart

## The critical fact

Flutter's HTTP stack (`dart:io` `HttpClient`, and therefore `dio`/`http` on it) **does not use the OS trust store or the system proxy** (OWASP **MASTG-TECH-0109**). Two consequences:

1. **You cannot pin via Android Network Security Config or iOS plist** — Flutter ignores them.
2. Pinning must be implemented **in Dart**, on the `HttpClient`/`SecurityContext` your client uses.

Pin to a certificate (or its public-key hash) you control. Re-pin before rotation, and ship a backup pin so a single cert rotation doesn't brick the app.

## Option A — SecurityContext with a bundled CA/leaf cert

Bundle the PEM as an asset (declare it under `flutter: assets:` in `pubspec.yaml`).

```dart
Future<SecurityContext> buildPinnedContext() async {
  final pem = await rootBundle.load('assets/certs/api.pem');
  return SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(pem.buffer.asUint8List());
}

// dio
final ctx = await buildPinnedContext();
(dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () =>
    HttpClient(context: ctx);
```

`withTrustedRoots: false` means *only* the bundled cert is trusted — the strictest form of pinning.

## Option B — public-key / fingerprint pinning in a callback

Pin the leaf's SHA-256 SPKI hash so the pin survives cert renewal as long as the key is unchanged.

```dart
const _pinnedSha256 = ['BASE64_SPKI_HASH_PRIMARY', 'BASE64_SPKI_HASH_BACKUP'];

HttpClient pinnedClient() {
  final client = HttpClient();
  client.badCertificateCallback = (cert, host, port) {
    final hash = base64.encode(sha256.convert(cert.der).bytes);
    return _pinnedSha256.contains(hash); // true ONLY for a matching pin
  };
  return client;
}
```

`badCertificateCallback` here is used **correctly**: it returns `true` only for a matching pin and `false` (reject) otherwise. That is the opposite of the anti-pattern below.

## Do / avoid

| Do | Avoid |
|---|---|
| Pin in Dart (`SecurityContext` or pin-checking callback) | Configure pinning in Android/iOS native code |
| Ship a **backup pin** and rotate ahead of expiry | A single pin that bricks the app on cert renewal |
| Return `true` from `badCertificateCallback` only on a real pin match | `badCertificateCallback = (c, h, p) => true` (disables TLS) |
| Pin the SPKI hash to survive cert (not key) rotation | Pinning a leaf cert that rotates frequently |
| Fail closed (reject) on mismatch | Falling back to an unpinned client on error |

## The critical anti-pattern

```dart
// CRITICAL AI MISTAKE — disables ALL TLS validation, app trusts any cert (MITM-able).
httpClient.badCertificateCallback = (cert, host, port) => true;
```
This shows up in "fix the SSL handshake error" answers. **Never ship it.** If you hit a handshake error in dev, fix the chain or add the dev CA to a *debug-only* `SecurityContext`; never blanket-trust in any build.

## Operational notes

- Test pin rotation: deploy the new cert's pin as the backup *before* swapping the server cert.
- Pinning raises the bar but does not stop a rooted attacker who can patch the binary — combine with `freerasp` integrity checks and server-side attestation.
- Keep pinned cert assets out of public VCS history if they reveal infra details.
