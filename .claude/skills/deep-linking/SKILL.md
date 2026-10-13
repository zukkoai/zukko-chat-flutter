---
name: deep-linking
description: Wires Flutter deep links — Android App Links, iOS Universal Links, custom schemes, and go_router handling. Use for assetlinks.json, apple-app-site-association, applinks entitlement, autoVerify, or links opening the browser instead of the app.
---

You are a Flutter engineer who wires verified deep links across Android, iOS, and go_router (Flutter 3.44 / Dart 3.12).

## When to use
- Adding App Links / Universal Links / custom-scheme deep links to an app.
- Links open the browser instead of the app, or cold-start links land on the wrong screen.
- Routing an incoming URL to the right screen, preserving it through auth.

## Detect first
Match the existing project — don't impose a parallel setup:
- Read `pubspec.lock`: is `go_router` present and which version? (It receives links natively — usually no `uni_links`/`app_links` needed.)
- **Android**: `android/app/src/main/AndroidManifest.xml` — existing `<intent-filter>`, `android:autoVerify`, scheme/host.
- **iOS**: `ios/Runner/Runner.entitlements` for `com.apple.developer.associated-domains`; Xcode "Associated Domains" capability.
- **Hosted files**: does the domain serve `/.well-known/assetlinks.json` and `/.well-known/apple-app-site-association`?
- Reuse the existing `GoRouter`; don't add a parallel link listener.

## Verified links vs custom schemes
| Type | Form | Trust |
|---|---|---|
| Android **App Links** | `https://example.com/...` + `autoVerify` | Verified, opens app directly, no chooser |
| iOS **Universal Links** | `https://example.com/...` + associated domains | Verified, opens app directly |
| Custom scheme | `myapp://path` | Unverified, weaker, any app can claim it |

Prefer verified `https://` links. Use custom schemes only as a fallback (e.g. OAuth redirect) or for internal flows.

## Native config is REQUIRED (AI usually omits it)
| Platform | Steps |
|---|---|
| **Android** | `<intent-filter>` with `android:autoVerify="true"`, `BROWSABLE`+`DEFAULT` categories, `https` scheme + host **and** host a `/.well-known/assetlinks.json` with your package + SHA-256 cert fingerprint |
| **iOS** | Add **Associated Domains** capability with `applinks:example.com` (in `Runner.entitlements`) **and** host `/.well-known/apple-app-site-association` (no extension, `Content-Type: application/json`, served over HTTPS, no redirects) |

**Without the hosted files + native config, verified links open the browser, not your app.** This is the #1 deep-link failure and the part AI most often skips.

## go_router integration
- go_router **receives the incoming link automatically** via the platform's default route — no manual listener needed in most apps.
- **Don't set `GoRouter(initialLocation: '/home')` when relying on deep links** — it clobbers the incoming link (known regression: the initial location wins over the launch URL). Omit `initialLocation`, or compute it from the launch intent.
- Handle **cold start** (app launched by the link) and **running** (app already open) — go_router covers both, but verify both paths in testing.

```dart
final router = GoRouter(
  // ❌ initialLocation: '/home',  // clobbers the deep link on cold start
  routes: $appRoutes,
  redirect: _authRedirect,
  refreshListenable: authNotifier,
);
```

## Auth + deep links
- The redirect must **preserve the intended destination** — capture it and return to it after login; don't drop the user on `/home`.
- Drive auth via **`refreshListenable`**, not `ref.watch`/`context.watch` inside `redirect` (cross-ref `navigation`).

```dart
String? _authRedirect(BuildContext context, GoRouterState state) {
  final loggedIn = authNotifier.isLoggedIn;
  final target = state.uri.toString();
  if (!loggedIn && target != '/login') return '/login?from=$target'; // preserve destination
  if (loggedIn && state.matchedLocation == '/login') {
    return state.uri.queryParameters['from'] ?? '/home';            // restore it
  }
  return null;
}
```

## Gotchas
- **No hosted verification file → browser opens, not the app.** `assetlinks.json` (Android) and `apple-app-site-association` (iOS) must be served over HTTPS at `/.well-known/`. Known AI mistake: configuring only the manifest/entitlement and forgetting the hosted file.
- **AASA filename/MIME trap:** the file is named `apple-app-site-association` with **no `.json` extension**, must return `Content-Type: application/json`, over HTTPS, and **must not redirect**. Wrong MIME or a redirect silently breaks verification. Known AI mistake: naming it `aasa.json` or letting a CDN redirect it.
- **`initialLocation` clobbers the deep link** on cold start — a known go_router regression. Don't set it when deep links matter.
- **Android `autoVerify` needs the right SHA-256:** debug and release builds have different signing certs → different fingerprints. List **both** debug and release SHA-256 in `assetlinks.json`, or release links won't verify. Known AI mistake: only the debug fingerprint.
- **iOS Universal Links don't work from Safari's address bar** typed directly or from the same domain — test via a link tapped from Notes/Messages/another app.
- **Custom schemes are unverified** — any app can register `myapp://`. Don't use them for security-sensitive flows; prefer App/Universal Links.
- **Auth redirect dropping the destination** sends every deep link to `/home` after login. Capture and restore it.

## Common mistakes
- Manifest/entitlement set but no hosted file → host `assetlinks.json` + AASA at `/.well-known/` over HTTPS.
- AASA named `*.json` or wrong MIME → no extension, `application/json`, no redirect.
- `initialLocation: '/home'` with deep links → remove it.
- Only debug SHA-256 in `assetlinks.json` → add the release fingerprint too.
- Auth redirect to `/home` losing the link → preserve `from` and restore after login.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, native config done, no leaks).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- Android manifest `<intent-filter>`, `autoVerify`, `assetlinks.json` hosting + SHA-256: read `reference/android-app-links.md`.
- iOS Associated Domains entitlement, AASA file + hosting/MIME rules: read `reference/ios-universal-links.md`.
- Receiving links in go_router, `initialLocation` pitfall, cold start, auth preservation: read `reference/go-router-integration.md`.
- Testing with `adb` / `xcrun simctl openurl` + verifying the hosted files: read `reference/testing-deep-links.md`.
