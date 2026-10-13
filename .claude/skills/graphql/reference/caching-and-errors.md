# Normalized cache, fetch policies & error mapping

The load-bearing details that make a GraphQL layer correct: cache identity, fetch
policies, mutation cache updates, and mapping the 200-with-`errors` response to the
`Result`/`Failure` from `error-handling`. Examples use graphql_flutter
types; the ferry equivalents are noted inline.

## Contents
- [Why normalization needs identity](#why-normalization-needs-identity)
- [Configuring identity (typePolicies / keyFields)](#configuring-identity-typepolicies--keyfields)
- [Fetch policies](#fetch-policies)
- [watchQuery vs query](#watchquery-vs-query)
- [Mutations must update the cache](#mutations-must-update-the-cache)
- [200-with-errors → Failure](#200-with-errors--failure)

## Why normalization needs identity
The cache stores each entity once, keyed by `${__typename}:${id}`. Any query or
mutation that returns the same entity merges into that one record, so every screen
watching it updates together. Drop `__typename`/`id` and the cache can't recognize
the entity → it can't merge a mutation result → **stale UI after a mutation**.

```graphql
# AVOID — no identity; the mutation result can't find the cached product
query { products { name price } }
mutation { updatePrice(id: "1", price: 9) { name price } }
```

```graphql
# DO — identity on both; the update merges into the cached entity automatically
query { products { __typename id name price } }
mutation { updatePrice(id: "1", price: 9) { __typename id name price } }
```

## Configuring identity (typePolicies / keyFields)
When an entity has no `id` field, tell the cache which field(s) identify it.

```dart
// graphql_flutter
GraphQLCache(
  store: InMemoryStore(),
  typePolicies: {
    'Product': TypePolicy(keyFields: {'sku': true}), // identity = __typename + sku
    'Settings': TypePolicy(keyFields: {}),           // singleton, no id needed
  },
);
// ferry: Cache(typePolicies: {'Product': TypePolicy(keyFields: {'sku': true})})
```

- Default identity is `__typename` + `id`/`_id` — only override for non-standard keys.
- Set a custom `dataIdFromObject` only if your whole schema uses one non-`id` key.

## Fetch policies
The default `cacheFirst` returns cached data and skips the network if present —
which is why fresh server data "doesn't show". Choose per query:

| Policy | Behavior | Use for |
|---|---|---|
| `cacheFirst` (default) | Cache if present, else network | Static/rarely-changing data |
| `cacheAndNetwork` | Emit cache immediately, then refresh from network | Lists/screens that must look current |
| `networkOnly` | Always hit the network, write to cache | Must-be-fresh reads |
| `cacheOnly` | Cache only, never network | Offline / known-cached reads |
| `noCache` | Network only, never read/write cache | One-off, sensitive, or huge payloads |

```dart
QueryOptions(document: gql(getProducts), fetchPolicy: FetchPolicy.cacheAndNetwork);
// ferry: GProductsReq((b) => b..fetchPolicy = FetchPolicy.CacheAndNetwork)
```

## watchQuery vs query
- `client.query(...)` runs **once** and returns a single `QueryResult`.
- `client.watchQuery(...).stream` (ferry: `client.request(req)`) returns a **stream**
  that re-emits whenever the cache changes — so a mutation elsewhere updates this
  screen with no extra fetch. Use it for live screens; feed the stream into a
  provider/bloc (`state-management`).

## Mutations must update the cache
A mutation does not auto-insert into or remove from a list. Pick one:

```dart
// 1) update callback — read the list, write the new item back
MutationOptions(
  document: gql(addProduct),
  update: (cache, result) {
    final req = Request(operation: Operation(document: gql(getProducts)));
    final existing = cache.readQuery(req) ?? {'products': []};
    cache.writeQuery(req, data: {
      'products': [...existing['products'], result?.data?['addProduct']],
    });
  },
);

// 2) optimisticResult — update the UI instantly, reconcile on response
MutationOptions(document: gql(addProduct), optimisticResult: {
  'addProduct': {'__typename': 'Product', 'id': 'temp', 'name': name},
});

// 3) refetch the affected query (simplest, costs a round-trip)
MutationOptions(document: gql(addProduct), refetchQueries: [
  Refetch(options: WatchQueryOptions(document: gql(getProducts))),
]);
```

Ferry: set `optimisticResponse` + `updateResult` on the request, or call
`cache.writeQuery` (see `reference/ferry-codegen.md`).

## 200-with-errors → Failure
GraphQL returns HTTP **200** even on errors: the body carries an `errors` array and
may still include partial `data`. Branching on status code alone misses these. Map
GraphQL errors AND link/network errors to the same `Failure` types from
`error-handling`, and still surface partial data when it's useful.

```dart
// graphql_flutter — one mapper in the repository boundary
Result<T> resultFrom<T>(QueryResult r, T Function(Map<String, dynamic>) parse) {
  final ex = r.exception;
  if (ex != null) {
    // network / socket / parse problem
    if (ex.linkException != null) return Failure(mapLink(ex.linkException!));
    // server returned errors[] with HTTP 200
    if (ex.graphqlErrors.isNotEmpty) {
      final code = ex.graphqlErrors.first.extensions?['code'];
      if (code == 'UNAUTHENTICATED') return const Failure(UnauthorizedFailure());
      return Failure(ServerFailure(ex.graphqlErrors.first.message));
    }
  }
  final data = r.data;
  if (data == null) return const Failure(UnexpectedFailure('No data'));
  return Success(parse(data)); // partial data: data may be non-null even with errors
}

AppFailure mapLink(LinkException e) => switch (e) {
  HttpLinkServerException() => const ServerFailure('Server error'),
  NetworkException() => const NetworkFailure(),
  _ => const UnexpectedFailure('Link error'),
};
```

```dart
// ferry equivalent — hasErrors covers GraphQL + link errors
AppFailure mapFerryErrors(OperationResponse response) {
  final link = response.linkException;
  if (link != null) return const NetworkFailure();
  final errs = response.graphqlErrors;
  if (errs != null && errs.isNotEmpty) return ServerFailure(errs.first.message);
  return const UnexpectedFailure('Unknown GraphQL error');
}
```

See `error-handling` for the `Result<T>` / `AppFailure` definitions and
exhaustive UI handling — this skill maps into them, it does not redefine them.
