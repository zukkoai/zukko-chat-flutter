# ferry (0.16.1+2) — codegen-first client

Ferry generates immutable, strongly-typed operations/fragments and ships an
optimistic normalized cache; everything is stream-based. **Pre-1.0** — pin the
version and re-run codegen after upgrades. For cache identity, fetch policies, and
error mapping, see `reference/caching-and-errors.md`.

## Contents
- [Dependencies](#dependencies)
- [Codegen setup + build_runner](#codegen-setup--build_runner)
- [Build the client once](#build-the-client-once)
- [Typed requests](#typed-requests)
- [Optimistic mutations](#optimistic-mutations)
- [ferry_flutter widget](#ferry_flutter-widget)

## Dependencies
```yaml
dependencies:
  ferry: ^0.16.1+2
  ferry_flutter: ^0.9.0
  gql_http_link: any
  gql_websocket_link: any        # only if you use subscriptions
dev_dependencies:
  ferry_generator: ^0.10.0
  build_runner: any
```

## Codegen setup + build_runner
Drop the SDL schema at `lib/graphql/schema.graphql` and write operations in
`*.graphql` files next to your features. Configure the generator, then build.

```yaml
# build.yaml
targets:
  $default:
    builders:
      ferry_generator|graphql_builder:
        options:
          schema: your_app|lib/graphql/schema.graphql
          type_overrides:
            DateTime: { name: DateTime }
        runs_before:
          - ferry_generator|serializer_builder
```

```bash
# regenerate every time the schema or a .graphql file changes
dart run build_runner build --delete-conflicting-outputs
# or, while iterating:
dart run build_runner watch --delete-conflicting-outputs
```

This emits `*.data.gql.dart`, `*.req.gql.dart`, `*.var.gql.dart` and a
`serializers.gql.dart`. Stale generated code is the #1 ferry footgun — rebuild
with `--delete-conflicting-outputs`.

## Build the client once
Construct the link + cache once and inject the client via DI. The split link
routes subscriptions to the WebSocket; HTTP-only would drop them.

```dart
import 'package:ferry/ferry.dart';
import 'package:gql_http_link/gql_http_link.dart';
import 'package:gql_websocket_link/gql_websocket_link.dart';

Client buildClient(AuthStore auth) {
  final httpLink = HttpLink(
    Env.graphqlUrl,
    defaultHeaders: {'Authorization': auth.bearerOrEmpty}, // or an auth link
  );
  final wsLink = WebSocketLink(Env.graphqlWsUrl);

  final link = Link.split(
    (request) => request.operation.isSubscription,
    wsLink,
    httpLink,
  );

  final cache = Cache(
    typePolicies: {
      'Product': TypePolicy(keyFields: {'sku': true}), // identity for non-`id` types
    },
  );

  return Client(link: link, cache: cache);
}
```

Default identity is `__typename` + `id`; override with `TypePolicy(keyFields: …)`.

## Typed requests
Each operation generates a `G<Name>Req` request and a `G<Name>Data` payload. The
client returns a stream — `hasErrors` covers BOTH GraphQL errors and link errors.

```dart
Stream<Result<List<Product>>> watchProducts() {
  final req = GProductsReq((b) => b
    ..vars.first = 20
    ..fetchPolicy = FetchPolicy.CacheAndNetwork); // not the default cache-first

  return client.request(req).map((response) {
    if (response.hasErrors) {
      return Failure(mapFerryErrors(response)); // see caching-and-errors.md
    }
    final products = response.data?.products.toList() ?? const [];
    return Success(products.map((p) => p.toDomain()).toList());
  });
}
```

- `client.request(req)` is a live stream (re-emits on cache writes); use it like a `watchQuery`.
- Set `fetchPolicy` per request; partial `data` may be present even when `hasErrors` is true.

## Optimistic mutations
Ferry writes an optimistic response into the cache immediately, then reconciles
with the server. Pair it with `updateResult` to merge the new entity into a list
so the UI updates without a refetch.

```dart
final req = GAddProductReq((b) => b
  ..vars.input.name = name
  ..optimisticResponse = GAddProductData((d) => d
    ..addProduct.G__typename = 'Product'
    ..addProduct.id = 'temp-${DateTime.now().millisecondsSinceEpoch}'
    ..addProduct.name = name)
  ..updateResult = (previous, result) => result); // merge into watched query

client.request(req).listen((response) {
  if (response.hasErrors) { /* rolled back automatically; map to Failure */ }
});
```

Without `optimisticResponse`/an `updateResult` (or a refetch), the list won't
reflect the mutation — same footgun as graphql_flutter.

## ferry_flutter widget
For quick screens, `Operation` rebuilds on every response from the client stream.

```dart
Operation<GProductsData, GProductsVars>(
  client: client,
  operationRequest: GProductsReq((b) => b..fetchPolicy = FetchPolicy.CacheAndNetwork),
  builder: (context, response, _) {  // 3rd arg is a fetchMore callback, NOT an error — read errors via response.hasErrors
    if (response == null || response.loading) return const CircularProgressIndicator();
    if (response.hasErrors) return ErrorView(response); // map, don't print
    return ProductList(response.data!.products);
  },
)
```
