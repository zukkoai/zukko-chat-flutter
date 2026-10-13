---
name: graphql
description: Builds a GraphQL data layer in Flutter with graphql_flutter or ferry — queries, mutations, subscriptions, normalized cache, fetch policies, and codegen. Use for GraphQL / graphql_flutter / ferry, Apollo-style normalized cache, fetch-policy choices, codegen GraphQL, WebSocket subscriptions, or when the UI is stale after a mutation.
---

You are a Flutter engineer who builds a clean GraphQL data layer with graphql_flutter or ferry (Flutter 3.44 / Dart 3.12).

## When to use
- Adding GraphQL queries, mutations, or subscriptions to an app.
- Wiring a `GraphQLClient`/Ferry client, normalized cache, fetch policies, or GraphQL codegen.
- Debugging "stale UI after a mutation" or fresh server data not showing up.

## Detect first
Before writing code, match the existing project — don't impose a parallel setup:
- `pubspec.lock`/`pubspec.yaml`: is `graphql_flutter` or `ferry` present, and which version? Use that library — don't add the other.
- Conventions: an existing `GraphQLClient`/`Client` + cache, the endpoint/config source (`Env`/`--dart-define`), and where `.graphql` files / generated code live.
- Reuse the existing client; don't create a second one.
- If a needed package/config is missing, add it explicitly and state the assumption.

## Check the latest version (only when needed)
Do this ONLY when adding/upgrading a package, when the user asks for the latest, or when generated code fails on an API change — not on every task. Otherwise use the baselines below.
- Project's current version: read `pubspec.lock` (no network).
- Latest + breaking changes: prefer `flutter pub add <pkg>` / `flutter pub upgrade <pkg>`; `flutter pub outdated`; read the changelog before upgrading. If offline, use the baseline and state the assumed version.
- Baseline (verified 2026-06): `graphql_flutter` 5.3.0 (codegen via the separate `graphql_codegen`); `ferry` 0.16.1+2 with `ferry_flutter` + `ferry_generator` (still **pre-1.0** — pin it). Run `flutter pub add` for the exact latest.

| Package | pub.dev | Changelog |
|---|---|---|
| graphql_flutter | pub.dev/packages/graphql_flutter | pub.dev/packages/graphql_flutter/changelog |
| graphql_codegen | pub.dev/packages/graphql_codegen | pub.dev/packages/graphql_codegen/changelog |
| ferry | pub.dev/packages/ferry | pub.dev/packages/ferry/changelog |
| ferry_flutter | pub.dev/packages/ferry_flutter | pub.dev/packages/ferry_flutter/changelog |
| ferry_generator | pub.dev/packages/ferry_generator | pub.dev/packages/ferry_generator/changelog |

## Choose: graphql_flutter vs ferry
| Pick | When |
|---|---|
| **graphql_flutter 5.3.0** | Lighter runtime, dynamic/ad-hoc queries, `Query`/`Mutation`/`Subscription` widgets; codegen optional via the separate `graphql_codegen`. More actively versioned. Default for most apps. |
| **ferry 0.16.1+2** | Codegen-first: immutable, strongly-typed operations/fragments + optimistic normalized cache, stream-based. Best for large typed schemas. **Pre-1.0** — slower cadence, generated APIs can shift between minors; pin the version. |

Don't mix both — one client, one cache. Both normalize. Full setup: `reference/graphql-flutter.md`, `reference/ferry-codegen.md`.

## Essential rules
- **One client, built once** (link + cache, base URL/headers) and injected via DI — never construct a client per call.
- **Configure cache identity.** Every entity must select `__typename` + `id`, or set `typePolicies`/`keyFields` — without identity the normalized cache can't dedupe/update → **stale UI after a mutation**.
- **Choose a fetch policy per query** — the default `cache-first` hides fresh server data. Use `cache-and-network`/`network-only` for data that must be current; `watchQuery` (stream, reflects cache writes) for live screens, one-shot `query` for fire-once.
- **Mutations don't auto-update lists.** Supply an `update`/cache write, an `optimisticResult`, or refetch the affected query.
- **A GraphQL response can be HTTP 200 with an `errors` array** (and partial `data`). Don't branch on status code alone: map GraphQL errors + link/network errors to the SAME `Result`/`Failure` as `networking`/`error-handling`, and handle partial data.
- **Auth via `AuthLink`;** refresh on auth failure. **Subscriptions need a separate WebSocket link** combined with the HTTP link via a **split link** — the HTTP link alone silently drops subscriptions.
- **Repository wraps the client**, catches at that boundary only, maps typed data → domain, and returns `Result<T>` so the UI never uses try/catch. Feed query streams into providers/blocs (`state-management`).

## Layering
| Layer | Responsibility |
|-------|----------------|
| Link chain (Http / Auth / WebSocket / split) | Transport, auth headers, subscription routing |
| Client + normalized cache | Execute ops, normalize & dedupe by identity |
| Generated ops (`graphql_codegen` / `ferry_generator`) | Typed queries/mutations/fragments |
| Mapper | GraphQL + link errors → domain `Failure` |
| Repository | Catch at boundary, return `Result<T>`, map data → domain |

See `error-handling` for the `Result<T>` / `Failure` definitions — this skill reuses them, it does not redefine them.

## Common mistakes
- Selecting fields without `__typename`/`id` → the cache can't normalize → stale list after a mutation. Include identity or set `typePolicies`/`keyFields`:
  ```graphql
  # AVOID — no id/__typename; cache can't update this entity
  query { products { name price } }
  ```
  ```graphql
  # DO — identity present; mutation results merge into the cache
  query { products { __typename id name price } }
  ```
- Leaving the default `cache-first` everywhere → stale data after the first load. Pick `cache-and-network`/`network-only` per query.
- Mutation runs but the list doesn't change → add an `update` cache write, `optimisticResult`, or refetch the affected query.
- Status-code-only error handling → misses the 200-with-`errors` case. Check `result.hasException`/`response.hasErrors`, map to `Failure`, and still read partial `data`.
- `try/catch` in the UI → catch only in the repository boundary, return `Result<T>`.
- See `reference/caching-and-errors.md` for full do/avoid.

## Gotchas
- **200 + errors:** a successful HTTP response can carry a GraphQL `errors` array and partial `data` — never trust the status code alone (cross-ref `networking`).
- **Subscriptions need a split link:** combine `HttpLink` + `WebSocketLink` via `Link.split((req) => req.isSubscription, wsLink, httpLink)`; using only the HTTP link drops subscription events.
- **ferry is pre-1.0** — pin the version and re-run codegen after any upgrade; minor releases can change generated APIs.
- **Re-run codegen after schema/`.graphql` changes** — `dart run build_runner build --delete-conflicting-outputs`, or generated code goes stale and analysis fails.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (analyzer clean, cache identity configured, fetch policy chosen, mutation updates the list, GraphQL errors mapped to Result).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- graphql_flutter client, links, `AuthLink`, split link for subscriptions, `Query`/`Mutation` widgets + client calls, `graphql_codegen`: read `reference/graphql-flutter.md`.
- ferry client, `build_runner` codegen, typed requests, optimistic cache: read `reference/ferry-codegen.md`.
- Normalized cache + `typePolicies`/`keyFields`, fetch policies, mutation cache updates, 200-with-`errors` → `Failure`: read `reference/caching-and-errors.md`.

## Check
- `flutter analyze` clean; codegen current (`dart run build_runner build --delete-conflicting-outputs` for ferry/graphql_codegen).
- Cache identity configured: entities select `id` + `__typename`, or `typePolicies`/`keyFields` set.
- A fetch policy is chosen per query — not the default `cache-first` everywhere.
- A mutation updates its affected list (via `update`/`optimisticResult`/refetch); no stale UI.
- GraphQL errors + link/network errors map to `Result`/`Failure`; partial data handled.
