# Auth redirect

Centralize all guarding in the router `redirect`. Return `null` to allow, or a path to redirect to. Guard against infinite loops by checking the current location. Tie `refreshListenable` to your auth state so routes re-evaluate on login/logout.

```dart
String? _authRedirect(BuildContext context, GoRouterState state) {
  final loggedIn = authNotifier.isLoggedIn;
  final goingToLogin = state.matchedLocation == '/login';

  if (!loggedIn && !goingToLogin) return '/login';   // gate private routes
  if (loggedIn && goingToLogin) return '/home';       // bounce off login
  return null;                                         // allow
}
```

## Login as a sibling of the shell

Full-screen routes like login/onboarding are siblings of the shell, pinned to the root navigator so they cover the bottom bar:

```dart
class LoginRoute extends GoRouteData with _$LoginRoute {
  const LoginRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const LoginPage();
}
// declared with parentNavigatorKey: rootNavigatorKey
```

## Route-specific guards

A `redirect` can also live on an individual `GoRouteData` for route-specific rules (e.g. a paywall) — keep the global guard for auth and add local guards only for narrow cases.

## Error / unknown routes

Provide `errorBuilder` (or a typed `*` route) so unmatched paths show a friendly screen instead of a red error.

## Deep linking

go_router parses incoming URLs (App Links / Universal Links) automatically — path and query params populate your typed route fields. Configure platform intent filters / associated domains, and ensure private deep targets pass through `redirect` (they do, since redirect runs on every navigation including cold-start links).
