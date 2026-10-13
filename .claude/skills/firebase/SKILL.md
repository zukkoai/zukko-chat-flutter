---
name: firebase
description: Integrates Firebase in Flutter — flutterfire configure, stream-based Auth, Firestore with offline persistence, and security rules. Use for firebase_auth, cloud_firestore, authStateChanges, firebase_options.dart, or App Check.
---

You are a Flutter + Firebase engineer who wires Auth, Firestore, and security rules correctly (Flutter 3.44 / Dart 3.12).

## When to use
- Adding/initializing Firebase, sign-in/sign-up, or an auth gate.
- Reading/writing Firestore, handling offline behavior, or building queries + converters.
- Writing or reviewing Firestore **security rules** and App Check.

## Detect first
Match the existing setup — don't re-init a second config:
- Read `pubspec.lock`: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_app_check` present and versions?
- Check for generated **`lib/firebase_options.dart`** and a `main()` that calls `Firebase.initializeApp(...)`.
- Native config files: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, and the google-services Gradle plugin in `android/app/build.gradle`.
- Existing `firestore.rules` / `firebase.json`. Reuse the project's auth solution and state-management wiring.

## Setup (essentials)
1. `dart pub global activate flutterfire_cli`, then **`flutterfire configure`** — registers apps and generates `lib/firebase_options.dart`. Never hand-write config.
2. Initialize before `runApp`:
```dart
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```
3. `flutter pub add firebase_core firebase_auth cloud_firestore` (run for latest). Native steps in `reference/setup.md`.

## Core rules

| Do | Avoid (AI mistake) |
|---|---|
| Drive UI from `authStateChanges()` stream | Reading `FirebaseAuth.instance.currentUser` on cold start (null until restored) |
| Use snapshot listeners or explicit `GetOptions(source:)` | Assuming `get()` is fresh — it can return stale cache |
| Ship real security rules with auth/ownership checks | `allow read, write: if true;` (test mode) in prod |
| Pair rules with **App Check** | Trusting the client; rules as the only guard with no attestation |
| `flutterfire configure` → `firebase_options.dart` | Hand-hardcoding API keys/config |

**Auth is a stream.** `currentUser` is **null on cold start** until the SDK restores the session, so a synchronous read at startup wrongly shows "logged out." Build the gate on `authStateChanges()` (or `idTokenChanges()` / `userChanges()`):
```dart
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (_, snap) => snap.hasData ? const HomePage() : const SignInPage(),
);
```

**Firestore offline persistence is ON by default on mobile.** So:
- `get()` may return **stale cached data**; for live data use `snapshots()`, or pass `GetOptions(source: Source.server)` (or `.cache`) deliberately.
- Writes are **optimistic and offline-queued** — `set/update` resolves locally and syncs later; don't treat a resolved Future as "the server accepted it."

**Security rules reject, they don't filter.** A query that *could* read documents the rules deny **fails entirely** — it does not silently narrow to allowed docs. Write queries that only ever touch permitted documents (e.g. `where('ownerId', isEqualTo: uid)`), and rules that match.

## Gotchas
- **`currentUser` read at startup is null** (known AI mistake) — use `authStateChanges()`; never gate on a synchronous read.
- **`get()` returns cached/stale data offline or after a recent write** (known AI mistake) — use listeners or `GetOptions(source:)`.
- **`allow read, write: if true;`** (top AI mistake) — test-mode rules left in prod expose the whole database. Replace before launch.
- **Rules don't filter queries** (known AI mistake) — a too-broad query throws `permission-denied` instead of returning a subset.
- **`firebase_options.dart` and `google-services.json`/`GoogleService-Info.plist` are config, not secrets** — but keep them out of public VCS; security comes from **rules + App Check**, not from hiding them.
- **Forgot `await Firebase.initializeApp` before use** → `[core/no-app]`. Initialize in `main` before `runApp`.
- **Hot-restart vs cold-start differ** for auth — test session restore on a real cold start, not just hot restart.

## Common mistakes
- Gating UI on `currentUser` at startup → use `authStateChanges()`.
- `get()` everywhere expecting fresh data → snapshot listeners or explicit source.
- Treating an offline write's resolved Future as server confirmation → handle eventual consistency.
- Shipping `if true` rules → enforce auth + ownership and add App Check.
- Broad queries the rules deny → scope the query (`where ownerId == uid`) to match the rules.

## Output contract
When this skill is active, keep responses tight and scannable:
- **Announce first:** before anything else, open the reply with a one-line marker that names **every** skill you actually invoked for this reply and what each is for — format `🛠️ Using <namespace:skill>[ + <namespace:skill> …] — <purpose>`. List all of them in the order you used them; never name just one when several fired. Examples: `🛠️ Using async — to make the fetch loop cancelable` · `🛠️ Using state-management + navigation + async — to wire the dark-mode view model`. Then continue with the answer.
- Lead with the fix or answer — no preamble, no restating the request.
- Organize by file: one-line purpose → code block → ≤3 bullets on what changed and why.
- Code first, prose second. Explain only what isn't obvious from the code.
- Short bullets, not paragraphs (each ≤2 lines); **bold** the key term.
- End with a **Check:** list of 2-5 concrete things to verify (builds, analyzer clean, native config done, no secrets).
- Don't pad length or echo the user's unchanged code back.

## Deep reference
- `flutterfire configure` + per-platform native steps (Gradle plugin, plist, App Check, emulators): read `reference/setup.md`.
- Stream-driven auth gate, providers, sign-in/up/out, with state management: read `reference/auth.md`.
- Firestore offline behavior, queries, snapshot listeners, `withConverter`: read `reference/firestore.md`.
- Rule patterns, auth/ownership checks, the `if true` anti-pattern, checklist: read `reference/security-rules.md`.
