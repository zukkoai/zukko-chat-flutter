# Hardening checklist (OWASP MASVS-aligned)

Mapped loosely to **OWASP MASVS** categories. Use MASTG for test procedures. Run through this before a security-sensitive release.

## Contents
- [Storage (MASVS-STORAGE)](#storage-masvs-storage)
- [Crypto & network (MASVS-CRYPTO / MASVS-NETWORK)](#crypto--network-masvs-crypto--masvs-network)
- [Auth (MASVS-AUTH)](#auth-masvs-auth)
- [Platform & integrity (MASVS-PLATFORM / MASVS-RESILIENCE)](#platform--integrity-masvs-platform--masvs-resilience)
- [Code & build (MASVS-CODE)](#code--build-masvs-code)
- [Packages](#packages)

## Storage (MASVS-STORAGE)
- [ ] Tokens/secrets in `flutter_secure_storage`, never `SharedPreferences` or plain files.
- [ ] No secrets logged (`debugPrint`/`print`) — redact tokens and auth headers.
- [ ] Sensitive data not written to caches, screenshots, or analytics breadcrumbs.
- [ ] Handle secure-storage read failures (Keystore reset / restore) as "logged out," not crash.
- [ ] Clear sensitive storage on logout (`deleteAll`) and consider clearing iOS Keychain on first run.

## Crypto & network (MASVS-CRYPTO / MASVS-NETWORK)
- [ ] All traffic over HTTPS; cleartext disabled (`android:usesCleartextTraffic="false"`, iOS ATS not weakened).
- [ ] TLS validation **never** disabled — no `badCertificateCallback => true` in any build.
- [ ] Cert/public-key pinning implemented **in Dart** (not native), with a backup pin.
- [ ] No homemade crypto; use vetted libraries; no hardcoded keys/IVs.

## Auth (MASVS-AUTH)
- [ ] Real auth enforced **server-side**; client checks are UX only.
- [ ] Short-lived access tokens + refresh flow; tokens revocable server-side.
- [ ] Biometric/PIN gate via `local_auth` for sensitive screens (not as the only auth).
- [ ] Session cleared on logout everywhere it lives.

## Platform & integrity (MASVS-PLATFORM / MASVS-RESILIENCE)
- [ ] Root/jailbreak + tamper/debugger detection via **`freerasp`** (not abandoned packages).
- [ ] Backend verifies the caller with **App Check** (Firebase) / **Play Integrity** (Android) / **DeviceCheck/App Attest** (iOS).
- [ ] Deep links / intent filters validated; no sensitive action triggerable by an unverified link.
- [ ] Sensitive screens excluded from screenshots/recents where required (`FLAG_SECURE` on Android).

## Code & build (MASVS-CODE)
- [ ] `--obfuscate --split-debug-info` for release (defense-in-depth, **not** secret protection).
- [ ] No secrets in source or `--dart-define`; `google-services.json`/`GoogleService-Info.plist` and infra-revealing configs gitignored.
- [ ] Debug-only code (loggers, dev CAs, test endpoints) guarded by `kDebugMode` and absent from release.
- [ ] Dependencies pinned and audited; `flutter pub outdated` clean of known-vulnerable versions.

## Packages
- `flutter_secure_storage` — token/secret storage.
- `freerasp` — runtime app self-protection (root/jailbreak/tamper/debugger).
- `local_auth` — biometric/PIN gate.
- App Check / Play Integrity / DeviceCheck — backend trust (configured in respective consoles).
