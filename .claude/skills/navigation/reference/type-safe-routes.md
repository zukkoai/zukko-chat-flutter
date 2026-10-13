# Type-safe routes (go_router_builder)

Declare routes as classes extending `GoRouteData`. Path and query params become typed fields. Generate with `dart run build_runner build -d`.

```yaml
dependencies:
  go_router: ^15.0.0
dev_dependencies:
  go_router_builder: ^3.0.0
  build_runner: ^2.4.0
```

```dart
part 'routes.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/home',
  routes: [TypedGoRoute<UserRoute>(path: 'user/:id')],
)
class HomeRoute extends GoRouteData with _$HomeRoute {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

class UserRoute extends GoRouteData with _$UserRoute {
  const UserRoute({required this.id, this.tab});
  final String id;          // from path :id
  final String? tab;        // from query ?tab=
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      UserPage(id: id, tab: tab);
}
```

Navigate with the generated objects — no string paths:

```dart
const UserRoute(id: '42', tab: 'posts').go(context);   // replace stack
const UserRoute(id: '42').push(context);               // push on top
```

## Passing non-serializable data

Prefer path/query params (deep-linkable). Use `extra` only for non-serializable objects within a session:

```dart
context.push('/checkout', extra: cart);
// in build: final cart = state.extra as Cart;
```

`extra` is lost on cold start / deep link — never use it for anything that must survive an app restart or a shared URL.
