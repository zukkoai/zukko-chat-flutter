# graphql_flutter (5.3.0)

Runtime GraphQL client with `Query`/`Mutation`/`Subscription` widgets and a
normalized cache. No built-in codegen — add `graphql_codegen` separately when you
want typed operations. For cache identity, fetch policies, mutation cache writes,
and error mapping, see `reference/caching-and-errors.md`.

## Contents
- [Dependencies](#dependencies)
- [Build the client once](#build-the-client-once)
- [AuthLink + token refresh](#authlink--token-refresh)
- [Split link for subscriptions](#split-link-for-subscriptions)
- [Client calls vs widgets](#client-calls-vs-widgets)
- [graphql_codegen (optional, typed)](#graphql_codegen-optional-typed)

## Dependencies
```yaml
dependencies:
  graphql_flutter: ^5.3.0
dev_dependencies:
  graphql_codegen: ^1.1.0   # optional typed-ops codegen — verify latest with `flutter pub add --dev graphql_codegen`
  build_runner: any
```

## Build the client once
Construct the link chain + cache once and inject the client via DI (`state-management`). Never build a client per call. Wrap a subtree in `GraphQLProvider` only if you use the `Query`/`Mutation` widgets.

```dart
import 'package:graphql_flutter/graphql_flutter.dart';

GraphQLClient buildClient(AuthStore auth) {
  final httpLink = HttpLink(Env.graphqlUrl); // from --dart-define, never hardcoded
  final authLink = AuthLink(getToken: () async {
    final t = auth.accessToken;
    return t == null ? null : 'Bearer $t';
  });

  return GraphQLClient(
    link: authLink.concat(httpLink),
    cache: GraphQLCache(
      store: InMemoryStore(),           // HiveStore() to persist across launches
      typePolicies: {                   // identity for entities without `id`
        'Product': TypePolicy(keyFields: {'sku': true}),
      },
    ),
    // optional: change the global default away from cache-first
    defaultPolicies: DefaultPolicies(
      query: Policies(fetch: FetchPolicy.cacheAndNetwork),
    ),
  );
}
```

- Default identity is `__typename` + `id`/`_id`; override per type with `TypePolicy(keyFields: …)`.
- Persist the cache with `HiveStore()` (call `await initHiveForFlutter()` in `main`).

## AuthLink + token refresh
`AuthLink.getToken` runs on every request, so it always sends the current token. On an auth failure (a GraphQL `UNAUTHENTICATED` error or a 401 link exception), refresh once and retry via a custom link or in the repository.

```dart
final authLink = AuthLink(getToken: () async => auth.bearerOrNull);

// Refresh-and-retry: catch the auth failure in the repository, refresh, re-run.
Future<Result<T>> withAuthRetry<T>(Future<Result<T>> Function() run) async {
  final first = await run();
  if (first case Failure(failure: UnauthorizedFailure())) {
    final ok = await auth.refresh();         // updates auth.accessToken
    if (ok) return run();                     // AuthLink picks up the new token
  }
  return first;
}
```

See `reference/caching-and-errors.md` for detecting `UNAUTHENTICATED` in the result.

## Split link for subscriptions
Subscriptions ride a WebSocket, not the HTTP POST. Route them with `Link.split` so queries/mutations go over HTTP and subscriptions over the socket. Using only the HTTP link silently drops subscription events.

```dart
final httpLink = HttpLink(Env.graphqlUrl);
final wsLink = WebSocketLink(
  Env.graphqlWsUrl,                                   // wss://…/graphql
  config: SocketClientConfig(
    autoReconnect: true,
    initialPayload: () async => {'Authorization': auth.bearerOrNull},
  ),
);

final link = Link.split(
  (request) => request.isSubscription,               // true → WebSocket
  wsLink,
  authLink.concat(httpLink),                          // queries/mutations
);
```

## Client calls vs widgets
Prefer direct client calls inside a repository (returns `Result<T>`); use the widgets only for quick screens.

```dart
// One-shot query (fire once).
final r = await client.query(QueryOptions(
  document: gql(getProducts),
  fetchPolicy: FetchPolicy.cacheAndNetwork,
));

// Live: watchQuery returns a stream that re-emits when the cache changes.
final stream = client.watchQuery(WatchQueryOptions(
  document: gql(getProducts),
  fetchPolicy: FetchPolicy.cacheAndNetwork,
)).stream;

// Mutation with an explicit cache update (see caching-and-errors.md).
await client.mutate(MutationOptions(document: gql(addProduct), variables: {...}));

// Subscription (needs the split link above).
final events = client.subscribe(SubscriptionOptions(document: gql(onProductAdded)));
```

```dart
// Widget form — handle loading + exception explicitly.
Query(
  options: QueryOptions(document: gql(getProducts), fetchPolicy: FetchPolicy.cacheAndNetwork),
  builder: (result, {fetchMore, refetch}) {
    if (result.hasException) return ErrorView(result.exception!); // map, don't print
    if (result.isLoading) return const CircularProgressIndicator();
    final products = result.data?['products'] as List? ?? const [];
    return ProductList(products);
  },
)
```

## graphql_codegen (optional, typed)
Generates typed `Options`/`Data` classes from `.graphql` files so you stop indexing untyped maps. Configure `build.yaml`, then run codegen.

```yaml
# build.yaml
targets:
  $default:
    builders:
      graphql_codegen:
        options:
          scalars:
            DateTime: { type: DateTime }
        generate_for:
          - lib/**/*.graphql
```

```bash
dart run build_runner build --delete-conflicting-outputs
```

Use the generated `Options$Query$…`/`Query$…` classes with `client.query`/`client.mutate` instead of raw `gql(...)` + map access. Re-run codegen after any schema or `.graphql` change.
