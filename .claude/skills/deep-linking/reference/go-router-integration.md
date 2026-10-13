# go_router deep-link integration

## Contents
- [How go_router receives links](#how-go_router-receives-links)
- [The initialLocation pitfall](#the-initiallocation-pitfall)
- [Cold start vs running](#cold-start-vs-running)
- [Auth: preserving the destination](#auth-preserving-the-destination)
- [Reading params from the link](#reading-params-from-the-link)

## How go_router receives links
With go_router as `MaterialApp.router`'s `routerConfig`, the platform delivers the launch/incoming URL to Flutter's router automatically. go_router parses it against your route table and navigates — you usually do **not** need `uni_links`/`app_links` or a manual `StreamSubscription`. The native config (App Links / Universal Links) is what gets the URL *to* Flutter; go_router takes it from there.

```dart
MaterialApp.router(routerConfig: router);
```

## The initialLocation pitfall
`GoRouter(initialLocation: '/home')` sets the starting route — but on a **cold start triggered by a deep link**, the initial location can **clobber the incoming URL**, dropping the user on `/home` instead of the linked screen. This is a known go_router regression.

```dart
// ❌ clobbers the deep link on cold start
final router = GoRouter(initialLocation: '/home', routes: $appRoutes);

// ✅ omit it when deep links matter — go_router uses the launch URL,
//    falling back to '/' (or your root route) when there's no link
final router = GoRouter(routes: $appRoutes, redirect: _authRedirect);
```
If you need a default for normal launches, handle it in `redirect` (e.g. redirect `'/'` → `'/home'`) rather than `initialLocation`, so a real deep link still wins.

## Cold start vs running
- **Cold start** — app launched *by* the link: go_router consumes the launch URL on startup. Verify the target screen builds with no prior navigation stack.
- **Running / background** — app already alive when the link arrives: go_router navigates to the new location, pushing onto the existing stack. Verify back-navigation makes sense.

Both are handled by go_router, but **test both** — they exercise different code paths (especially around auth redirect and missing state).

## Auth: preserving the destination
A naive redirect sends every unauthenticated deep link to login and then to `/home`, losing where the user was going. Capture the intended URL and restore it after login. Drive auth with `refreshListenable`, not `ref.watch` inside `redirect` (see `navigation`).

```dart
final router = GoRouter(
  routes: $appRoutes,
  refreshListenable: authNotifier,        // re-runs redirect on auth change
  redirect: (context, state) {
    final loggedIn = authNotifier.isLoggedIn;
    final goingToLogin = state.matchedLocation == '/login';
    if (!loggedIn && !goingToLogin) {
      return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
    }
    if (loggedIn && goingToLogin) {
      final from = state.uri.queryParameters['from'];
      return from != null ? Uri.decodeComponent(from) : '/home';
    }
    return null;
  },
);
```
- `from` carries the originally-requested deep link through the login flow.
- After successful login, `refreshListenable` fires, redirect re-runs, and the user lands on `from`.

## Reading params from the link
A link like `https://example.com/product/42?ref=email` maps to a route; read params from `GoRouterState`:
```dart
GoRoute(
  path: '/product/:id',
  builder: (context, state) => ProductScreen(
    id: state.pathParameters['id']!,
    ref: state.uri.queryParameters['ref'],
  ),
);
```
Prefer **path/query params** over `extra:` for deep links — they survive cold start and are reconstructable from the URL; `extra` is null on a cold-start deep link.
