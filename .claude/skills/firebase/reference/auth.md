# Firebase Auth — stream-driven gate

## The core principle

Auth state is **asynchronous and restored after launch**. `FirebaseAuth.instance.currentUser` is **null on cold start** until the SDK rehydrates the session. Never gate UI on a synchronous read — listen to a stream.

| Stream | Fires on |
|---|---|
| `authStateChanges()` | Sign-in, sign-out, and initial restore — use for the app's auth gate |
| `idTokenChanges()` | Above + token refresh (use when you need fresh token/claims) |
| `userChanges()` | Above + profile updates (`updateDisplayName`, reload) |

## Auth gate

```dart
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.hasData ? const HomePage() : const SignInPage();
        },
      );
}
```

The `waiting` branch covers the brief restore window — without it you flash the sign-in screen on every launch.

## With state management

Expose the stream through your container so the whole app reacts.

```dart
// Riverpod
@riverpod
Stream<User?> authState(Ref ref) => FirebaseAuth.instance.authStateChanges();
// UI: ref.watch(authStateProvider).when(data: ..., loading: ..., error: ...)
```

```dart
// Bloc/Cubit: subscribe in the constructor, emit on each event, cancel in close().
_sub = FirebaseAuth.instance.authStateChanges().listen((u) => emit(AuthState(u)));
```

## Sign in / up / out

```dart
final auth = FirebaseAuth.instance;

await auth.createUserWithEmailAndPassword(email: e, password: p);
await auth.signInWithEmailAndPassword(email: e, password: p);
await auth.signOut();
await auth.currentUser?.sendEmailVerification();
```

Catch `FirebaseAuthException` and map `e.code` to user-facing messages:

```dart
try {
  await auth.signInWithEmailAndPassword(email: e, password: p);
} on FirebaseAuthException catch (err) {
  final msg = switch (err.code) {
    'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Email or password is incorrect.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'network-request-failed' => 'No connection.',
    _ => 'Sign-in failed.',
  };
  // surface msg
}
```

## Providers (Google / Apple)

```dart
// Google: pair google_sign_in to get credentials, then:
final cred = GoogleAuthProvider.credential(idToken: idToken, accessToken: accessToken);
await auth.signInWithCredential(cred);
```
- Google: add SHA-1/SHA-256 (Android) and reversed-client-ID URL scheme (iOS).
- Apple: required if you offer other social logins on iOS; configure the capability in Xcode.

## Gotchas

- Don't render the gate off `currentUser` directly — use the stream; `currentUser` is for one-off reads *after* you know a user exists.
- Reading custom claims after a role change needs `getIdToken(true)` (force refresh) or `idTokenChanges()`.
- Sign-out doesn't clear other local state (Firestore cache, your own stores) — clear those too.
- Test session persistence on a **cold start**, not hot restart.
