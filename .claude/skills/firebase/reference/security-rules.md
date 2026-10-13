# Firestore security rules

Rules run **server-side** and are the real authorization boundary — the client cannot be trusted. Pair them with App Check.

## Contents
- [The if-true anti-pattern](#the-if-true-anti-pattern)
- [Rules reject, they don't filter](#rules-reject-they-dont-filter)
- [Auth + ownership patterns](#auth--ownership-patterns)
- [Validation on write](#validation-on-write)
- [Testing rules](#testing-rules)
- [Checklist](#checklist)

## The if-true anti-pattern

```javascript
// TOP AI MISTAKE — test-mode rules. Anyone can read/write your entire database.
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;   // NEVER ship this
    }
  }
}
```
`flutterfire`/console scaffolds may leave "test mode" rules with an expiry. **Replace them before launch.** A single `if true` exposes the whole database regardless of how careful your client code is.

## Rules reject, they don't filter

A query that could read documents the rules deny **fails with `permission-denied`** — Firestore does **not** silently return only the allowed subset. So your client query must match your rules:

```dart
// Rules: allow read if resource.data.ownerId == request.auth.uid
// Client MUST scope the query, or it throws:
col.where('ownerId', isEqualTo: uid).snapshots();  // OK
col.snapshots();                                    // permission-denied
```

## Auth + ownership patterns

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() { return request.auth != null; }
    function isOwner(uid) { return isSignedIn() && request.auth.uid == uid; }

    match /users/{uid} {
      allow read: if isOwner(uid);
      allow write: if isOwner(uid);
    }

    match /todos/{todoId} {
      allow read:   if isOwner(resource.data.ownerId);
      allow create: if isOwner(request.resource.data.ownerId);
      allow update, delete: if isOwner(resource.data.ownerId);
    }
  }
}
```
- `resource.data` = the existing doc; `request.resource.data` = the incoming doc (use it for `create`/`update`).
- Split `read` into `get`/`list` and `write` into `create`/`update`/`delete` when they need different rules.

## Validation on write

Rules can enforce shape and immutability, not just access:

```javascript
allow create: if isOwner(request.resource.data.ownerId)
  && request.resource.data.title is string
  && request.resource.data.title.size() <= 200
  && request.resource.data.ownerId == request.auth.uid;

allow update: if isOwner(resource.data.ownerId)
  && request.resource.data.ownerId == resource.data.ownerId; // ownerId can't change
```

## Testing rules

- Use the **Emulator Suite** + `@firebase/rules-unit-testing` to assert allowed/denied access before deploying.
- Test both the happy path and that denied access actually throws.

```bash
firebase deploy --only firestore:rules
```

## Checklist

- [ ] No `if true` / test-mode rules anywhere in production.
- [ ] Default deny: only explicitly-matched paths are allowed.
- [ ] Every read/write checks `request.auth != null` and ownership/role.
- [ ] Client queries scoped to match rules (no `permission-denied` from over-broad reads).
- [ ] Writes validate shape and protect immutable fields (e.g. `ownerId`).
- [ ] App Check enforced on Firestore once verified.
- [ ] Rules covered by emulator tests; deployed via `firebase deploy --only firestore:rules`.
