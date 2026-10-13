# iOS Universal Links

## Contents
- [Two required pieces](#two-required-pieces)
- [1. Associated Domains entitlement](#1-associated-domains-entitlement)
- [2. Host apple-app-site-association (AASA)](#2-host-apple-app-site-association-aasa)
- [The AASA footguns](#the-aasa-footguns)
- [Getting your App ID prefix](#getting-your-app-id-prefix)
- [Custom scheme (fallback)](#custom-scheme-fallback)

## Two required pieces
A Universal Link opens your app directly only when **both** are true:
1. The app has the **Associated Domains** entitlement listing `applinks:example.com`.
2. The domain serves a valid **`apple-app-site-association`** file at `/.well-known/` over HTTPS.

Miss either and the link opens Safari.

## 1. Associated Domains entitlement
In Xcode: select the Runner target → **Signing & Capabilities** → **+ Capability** → **Associated Domains** → add:
```
applinks:example.com
```
This writes to `ios/Runner/Runner.entitlements`:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:example.com</string>
</array>
```
- One entry per domain (`applinks:www.example.com` is distinct from `applinks:example.com` — add both if you serve both).
- The capability must also be enabled for the App ID in the Apple Developer portal.

## 2. Host apple-app-site-association (AASA)
Serve at `https://example.com/.well-known/apple-app-site-association`:
```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["ABCDE12345.com.example.app"],
        "components": [
          { "/": "/app/*", "comment": "matches /app/..." }
        ]
      }
    ]
  }
}
```
- `appIDs` = `<TeamID>.<bundleId>`.
- `components` (modern) replaces the older `paths` array; `paths` still works but `components` is current.

## The AASA footguns
These break verification silently — Apple just opens Safari with no error:
- **No file extension.** It is literally `apple-app-site-association`, **not** `aasa.json` or `apple-app-site-association.json`.
- **MIME type must be `application/json`.** Configure your server/CDN to serve it as JSON. Wrong `Content-Type` fails verification.
- **HTTPS with a valid cert, and NO redirects.** A 301/302 (even http→https or a CDN rewrite) breaks it. Serve the file directly with a 200.
- **Reachable at `/.well-known/`.** (Apple historically also checked the domain root; `/.well-known/` is the standard location.)
- **Cached for hours.** iOS caches AASA; after changing it, test on a fresh install or wait for the cache to expire.

## Getting your App ID prefix
Team ID is in Apple Developer portal → Membership, or:
```bash
# from a built app's embedded.mobileprovision, or simply read it in Xcode under Signing
```
`appIDs` entry = `TEAMID.bundleIdentifier`, e.g. `ABCDE12345.com.example.app`.

## Custom scheme (fallback)
For an unverified custom scheme (OAuth redirect, internal), add to `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>myapp</string></array>
  </dict>
</array>
```
Custom schemes are unverified — prefer Universal Links for anything user-facing or security-sensitive.
